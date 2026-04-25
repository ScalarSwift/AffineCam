import CoreMedia

protocol EngineProvider: Sendable {
    func start(frameInbox: FrameInbox) async
}
