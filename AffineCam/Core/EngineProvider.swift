import CoreMedia

protocol EngineProvider: Sendable {
    var frameStream: AsyncStream<CMSampleBuffer> { get }
    func start() async
}
