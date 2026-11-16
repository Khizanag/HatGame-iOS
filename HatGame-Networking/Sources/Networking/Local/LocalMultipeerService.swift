//
//  LocalMultipeerService.swift
//  Networking
//
//  Created by Giga Khizanishvili on 21.05.26.
//

import Foundation
@preconcurrency import MultipeerConnectivity
import OSLog

private let logger = Logger(subsystem: "com.khizanag.hat-game", category: "MultipeerService")

/// Thin wrapper around Apple's `MultipeerConnectivity` framework. Owns one
/// `MCSession` plus either an `MCNearbyServiceAdvertiser` (host) or an
/// `MCNearbyServiceBrowser` (guest). Sends/receives `LocalMessage`
/// envelopes via the session.
///
/// Main-actor isolated: Multipeer calls its delegates on private queues.
/// Every delegate callback is yielded into one `AsyncStream` that a single
/// main-actor task drains, so events are handled in the order they arrived
/// — a peer's `.connected` before its first message, a message before the
/// disconnect that followed it. A `Task` per callback guarantees no order.
@MainActor
public final class LocalMultipeerService: NSObject {
    /// Service type advertised over Bonjour. Must be 1-15 chars, lowercase
    /// letters / digits / hyphens. Registered in Info.plist via
    /// NSBonjourServices.
    public static let serviceType = "hg-hat-game"

    public enum Role: Sendable {
        case host
        case guest
    }

    public enum ConnectionError: Error, LocalizedError {
        case notBrowsing
        case declined
        case timedOut

        public var errorDescription: String? {
            switch self {
            case .notBrowsing: "Start looking for nearby rooms before joining one."
            case .declined: "The host's device didn't accept the connection. Try again."
            case .timedOut: "Couldn't reach the host. Make sure you're both on the same Wi-Fi or have Bluetooth on."
            }
        }
    }

    public struct DiscoveredHost: Identifiable, Hashable {
        public let id: MCPeerID
        public let displayName: String
        /// Optional metadata advertised by the host (e.g. host player name).
        public let discoveryInfo: [String: String]

        /// False when the host runs a different nearby protocol version.
        public var isCompatible: Bool {
            LocalProtocol.isCompatible(discoveryInfo: discoveryInfo)
        }
    }

    /// One in-flight `connect(to:)`; resolved exactly once by the peer's
    /// state change, the timeout, cancellation, or `endSession()`.
    private struct PendingConnection {
        let peer: MCPeerID
        let continuation: CheckedContinuation<Void, Error>
        let timeout: Task<Void, Never>
    }

    /// Multipeer requires the invitation handler to be called exactly once,
    /// from any thread; the box carries it across to the main actor.
    fileprivate struct InvitationReply: @unchecked Sendable {
        let respond: (Bool, MCSession?) -> Void
    }

    /// One delegate callback, carried to the main actor. The Multipeer
    /// objects inside are only touched there.
    fileprivate enum Event: @unchecked Sendable {
        case stateChange(MCPeerID, MCSessionState, MCSession)
        case message(LocalMessage, MCPeerID, MCSession)
        case invitation(MCNearbyServiceAdvertiser, InvitationReply)
        case hostFound(DiscoveredHost)
        case hostLost(MCPeerID)
    }

    // MARK: - State
    public private(set) var role: Role?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var pendingConnection: PendingConnection?
    private let peerID: MCPeerID
    /// Delegate callbacks enter here from Multipeer's queues…
    private nonisolated let eventSink: AsyncStream<Event>.Continuation
    /// …and are handled here, one at a time, on the main actor.
    private var eventPump: Task<Void, Never>?

    // MARK: - Callbacks
    /// Fired when a peer's MCSessionState changes. Host typically reacts to
    /// `.connected` by sending the current snapshot to the new peer.
    public var onPeerStateChange: (@MainActor (MCPeerID, MCSessionState) -> Void)?
    /// Fired when a message arrives from a peer.
    public var onMessage: (@MainActor (LocalMessage, MCPeerID) -> Void)?
    /// Guest-only. Fired when the browser sees / loses a nearby host.
    public var onHostFound: (@MainActor (DiscoveredHost) -> Void)?
    public var onHostLost: (@MainActor (MCPeerID) -> Void)?

    // MARK: - Init
    public init(displayName: String) {
        let trimmed = String(displayName.prefix(63)) // MCPeerID limit
        self.peerID = MCPeerID(displayName: trimmed.isEmpty ? "Player" : trimmed)
        let (events, sink) = AsyncStream.makeStream(of: Event.self)
        self.eventSink = sink
        super.init()
        eventPump = Task { [weak self] in
            for await event in events {
                self?.handle(event)
            }
        }
    }

    isolated deinit {
        eventSink.finish()
        eventPump?.cancel()
        endSession()
    }

    public var connectedPeers: [MCPeerID] {
        session?.connectedPeers ?? []
    }

    public var localPeerID: MCPeerID { peerID }

    // MARK: - Host advertising
    public func startHosting(discoveryInfo: [String: String]) {
        endSession()
        role = .host
        session = makeSession()

        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: discoveryInfo,
            serviceType: Self.serviceType
        )
        advertiser.delegate = self
        self.advertiser = advertiser
        advertiser.startAdvertisingPeer()
        logger.info("Started hosting as \(self.peerID.displayName, privacy: .public)")
    }

    // MARK: - Guest browsing
    /// Starts (or resumes) looking for hosts. Keeps an existing guest session
    /// so a connection that is already up survives.
    public func startBrowsing() {
        if role == .host {
            endSession()
        }
        role = .guest
        if session == nil {
            session = makeSession()
        }
        if browser == nil {
            let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
            browser.delegate = self
            self.browser = browser
        }
        browser?.startBrowsingForPeers()
        logger.info("Started browsing as \(self.peerID.displayName, privacy: .public)")
    }

    /// Stops discovery only. The session — and any connection to a host —
    /// stays up.
    public func stopBrowsing() {
        browser?.stopBrowsingForPeers()
    }

    /// Invites `host` into the existing guest session and waits until the
    /// peer reports `.connected`.
    public func connect(to host: MCPeerID, timeout: Duration = .seconds(15)) async throws {
        guard let browser, let session else { throw ConnectionError.notBrowsing }
        guard !session.connectedPeers.contains(host) else { return }
        resolvePendingConnection(with: .failure(CancellationError()))

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: timeout)
                    guard !Task.isCancelled else { return }
                    self?.resolvePendingConnection(with: .failure(ConnectionError.timedOut))
                }
                pendingConnection = PendingConnection(peer: host, continuation: continuation, timeout: timeoutTask)
                browser.invitePeer(
                    host,
                    to: session,
                    withContext: nil,
                    timeout: TimeInterval(timeout.components.seconds)
                )
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.resolvePendingConnection(with: .failure(CancellationError()))
            }
        }
    }

    /// Tears down discovery, advertising, and the session.
    public func endSession() {
        resolvePendingConnection(with: .failure(CancellationError()))
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session?.disconnect()
        session = nil
        role = nil
    }

    // MARK: - Sending
    public func send(_ message: LocalMessage, to peers: [MCPeerID]? = nil) {
        guard let session else { return }
        let recipients = peers ?? session.connectedPeers
        guard !recipients.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: recipients, with: .reliable)
        } catch {
            logger.error("send failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Event handling
private extension LocalMultipeerService {
    func makeSession() -> MCSession {
        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        return session
    }

    func handle(_ event: Event) {
        switch event {
        case let .stateChange(peer, state, session):
            handleStateChange(state, peer: peer, in: session)
        case let .message(message, peer, session):
            handleMessage(message, from: peer, in: session)
        case let .invitation(advertiser, reply):
            handleInvitation(from: advertiser, reply: reply)
        case let .hostFound(host):
            onHostFound?(host)
        case let .hostLost(peer):
            onHostLost?(peer)
        }
    }

    func resolvePendingConnection(with result: Result<Void, Error>) {
        guard let pending = pendingConnection else { return }
        pendingConnection = nil
        pending.timeout.cancel()
        pending.continuation.resume(with: result)
    }

    /// Events from a session this service has already replaced or ended are
    /// dropped, so a late callback cannot resurrect a torn-down connection.
    func handleStateChange(_ state: MCSessionState, peer: MCPeerID, in session: MCSession) {
        guard session === self.session else { return }
        if pendingConnection?.peer == peer {
            switch state {
            case .connected: resolvePendingConnection(with: .success(()))
            case .notConnected: resolvePendingConnection(with: .failure(ConnectionError.declined))
            default: break
            }
        }
        onPeerStateChange?(peer, state)
    }

    func handleMessage(_ message: LocalMessage, from peer: MCPeerID, in session: MCSession) {
        guard session === self.session else { return }
        onMessage?(message, peer)
    }

    func handleInvitation(from advertiser: MCNearbyServiceAdvertiser, reply: InvitationReply) {
        // Open-lobby policy: accept every guest while hosting. The host's
        // RoomRules still decide whether the announced player is admitted.
        guard advertiser === self.advertiser, let session else {
            reply.respond(false, nil)
            return
        }
        reply.respond(true, session)
    }
}

// MARK: - MCSessionDelegate
extension LocalMultipeerService: MCSessionDelegate {
    nonisolated public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        eventSink.yield(.stateChange(peerID, state, session))
    }

    nonisolated public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let message: LocalMessage
        do {
            message = try JSONDecoder().decode(LocalMessage.self, from: data)
        } catch {
            logger.error("decode failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        eventSink.yield(.message(message, peerID, session))
    }

    nonisolated public func session(
        _: MCSession,
        didReceive _: InputStream,
        withName _: String,
        fromPeer _: MCPeerID
    ) {}

    nonisolated public func session(
        _: MCSession,
        didStartReceivingResourceWithName _: String,
        fromPeer _: MCPeerID,
        with _: Progress
    ) {}

    nonisolated public func session(
        _: MCSession,
        didFinishReceivingResourceWithName _: String,
        fromPeer _: MCPeerID,
        at _: URL?,
        withError _: Error?
    ) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate (host)
extension LocalMultipeerService: MCNearbyServiceAdvertiserDelegate {
    nonisolated public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer _: MCPeerID,
        withContext _: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        eventSink.yield(.invitation(advertiser, InvitationReply(respond: invitationHandler)))
    }

    nonisolated public func advertiser(_: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.error("advertiser failed: \(error.localizedDescription, privacy: .public)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate (guest)
extension LocalMultipeerService: MCNearbyServiceBrowserDelegate {
    nonisolated public func browser(
        _: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        let host = DiscoveredHost(id: peerID, displayName: peerID.displayName, discoveryInfo: info ?? [:])
        eventSink.yield(.hostFound(host))
    }

    nonisolated public func browser(_: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        eventSink.yield(.hostLost(peerID))
    }

    nonisolated public func browser(_: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.error("browser failed: \(error.localizedDescription, privacy: .public)")
    }
}
