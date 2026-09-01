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
/// All callbacks land on the main run loop because consumers in this app
/// are `@MainActor`-isolated.
public final class LocalMultipeerService: NSObject, @unchecked Sendable {
    /// Service type advertised over Bonjour. Must be 1-15 chars, lowercase
    /// letters / digits / hyphens. Registered in Info.plist via
    /// NSBonjourServices.
    public static let serviceType = "hg-hat-game"

    public enum Role: Sendable {
        case host
        case guest
    }

    public struct DiscoveredHost: Identifiable, Hashable {
        public let id: MCPeerID
        public let displayName: String
        /// Optional metadata advertised by the host (e.g. host player name).
        public let discoveryInfo: [String: String]
    }

    // MARK: - State
    public private(set) var role: Role?
    public private(set) var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let peerID: MCPeerID

    // MARK: - Callbacks
    // Set by the owning manager — closures fire on the main queue.

    /// Fired when a peer's MCSessionState changes. Host typically reacts to
    /// `.connected` by sending the current snapshot to the new peer.
    public var onPeerStateChange: ((MCPeerID, MCSessionState) -> Void)?
    /// Fired when a message arrives from a peer.
    public var onMessage: ((LocalMessage, MCPeerID) -> Void)?
    /// Guest-only. Fired when the browser sees / loses a nearby host.
    public var onHostFound: ((DiscoveredHost) -> Void)?
    public var onHostLost: ((MCPeerID) -> Void)?
    /// Host-only. Fired when a guest invites itself. Default: always accept.
    public var onInvitationReceived: ((MCPeerID, (Bool) -> Void) -> Void)?

    // MARK: - Init
    public init(displayName: String) {
        let trimmed = String(displayName.prefix(63)) // MCPeerID limit
        self.peerID = MCPeerID(displayName: trimmed.isEmpty ? "Player" : trimmed)
        super.init()
    }

    deinit {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
    }

    // MARK: - Host advertising
    public func startHosting(discoveryInfo: [String: String]) {
        stop()
        role = .host

        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

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
    public func startBrowsing() {
        stop()
        role = .guest

        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self
        self.browser = browser
        browser.startBrowsingForPeers()
        logger.info("Started browsing as \(self.peerID.displayName, privacy: .public)")
    }

    public func invite(host: MCPeerID, withContext context: Data? = nil, timeout: TimeInterval = 30) {
        guard let browser, let session else { return }
        browser.invitePeer(host, to: session, withContext: context, timeout: timeout)
    }

    public func stop() {
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

    public var connectedPeers: [MCPeerID] {
        session?.connectedPeers ?? []
    }

    public var localPeerID: MCPeerID { peerID }
}

// MARK: - MCSessionDelegate
extension LocalMultipeerService: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            self?.onPeerStateChange?(peerID, state)
        }
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try JSONDecoder().decode(LocalMessage.self, from: data)
            DispatchQueue.main.async { [weak self] in
                self?.onMessage?(message, peerID)
            }
        } catch {
            logger.error("decode failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {}
    public func session(_: MCSession, didStartReceivingResourceWithName _: String, fromPeer _: MCPeerID, with _: Progress) {}
    public func session(_: MCSession, didFinishReceivingResourceWithName _: String, fromPeer _: MCPeerID, at _: URL?, withError _: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate (host)
extension LocalMultipeerService: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(
        _: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer _: MCPeerID,
        withContext _: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // Open-lobby policy: accept every guest. (Party game; the host can
        // still kick or close the lobby from the UI.)
        invitationHandler(true, session)
    }

    public func advertiser(_: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        logger.error("advertiser failed: \(error.localizedDescription, privacy: .public)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate (guest)
extension LocalMultipeerService: MCNearbyServiceBrowserDelegate {
    public func browser(_: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let host = DiscoveredHost(
            id: peerID,
            displayName: peerID.displayName,
            discoveryInfo: info ?? [:]
        )
        DispatchQueue.main.async { [weak self] in
            self?.onHostFound?(host)
        }
    }

    public func browser(_: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.onHostLost?(peerID)
        }
    }

    public func browser(_: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.error("browser failed: \(error.localizedDescription, privacy: .public)")
    }
}
