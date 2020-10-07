/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
@testable import Datadog

class DDURLSessionDelegateTests: XCTestCase {
    private let interceptor = URLSessionInterceptorMock()
    private lazy var delegate = DDURLSessionDelegate(interceptor: interceptor)

    // MARK: - Interception Flow

    func testGivenURLSessionWithDatadogDelegate_whenUsingTaskWithURL_itNotifiesInterceptor() {
        let notifyTaskCompleted = expectation(description: "Notify task completion")
        let notifyTaskMetricsCollected = expectation(description: "Notify task metrics collection")
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200), data: .mock(ofSize: 10)))

        interceptor.onTaskCompleted = { _, _, _ in notifyTaskCompleted.fulfill() }
        interceptor.onTaskMetricsCollected = { _, _, _ in notifyTaskMetricsCollected.fulfill() }

        // Given
        let session = URLSession.createServerMockURLSession(delegate: delegate)

        // When
        let task = session.dataTask(with: URL.mockAny())
        task.resume()

        // Then
        wait(for: [notifyTaskMetricsCollected, notifyTaskCompleted], timeout: 0.5, enforceOrder: true)
        _ = server.waitAndReturnRequests(count: 1)
    }

    func testGivenURLSessionWithDatadogDelegate_whenUsingTaskWithURLRequest_itNotifiesInterceptor() {
        let notifyTaskCompleted = expectation(description: "Notify task completion")
        let notifyTaskMetricsCollected = expectation(description: "Notify task metrics collection")
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200), data: .mock(ofSize: 10)))

        interceptor.onTaskCompleted = { _, _, _ in notifyTaskCompleted.fulfill() }
        interceptor.onTaskMetricsCollected = { _, _, _ in notifyTaskMetricsCollected.fulfill() }

        // Given
        let session = URLSession.createServerMockURLSession(delegate: delegate)

        // When
        let task = session.dataTask(with: URLRequest.mockAny())
        task.resume()

        // Then
        wait(for: [notifyTaskMetricsCollected, notifyTaskCompleted], timeout: 0.5, enforceOrder: true)
        _ = server.waitAndReturnRequests(count: 1)
    }

    // MARK: - Interception Values

    func testGivenURLSessionWithDatadogDelegate_whenTaskCompletesWithFailure_itPassessAllValuesToTheInterceptor() throws {
        let notifyTaskCompleted = expectation(description: "Notify task completion")
        let notifyTaskMetricsCollected = expectation(description: "Notify task metrics collection")
        notifyTaskCompleted.expectedFulfillmentCount = 2
        notifyTaskMetricsCollected.expectedFulfillmentCount = 2

        let expectedError = NSError(domain: "network", code: 999, userInfo: [NSLocalizedDescriptionKey: "some error"])
        let server = ServerMock(delivery: .failure(error: expectedError))

        interceptor.onTaskCompleted = { _, _, _ in notifyTaskCompleted.fulfill() }
        interceptor.onTaskMetricsCollected = { _, _, _ in notifyTaskMetricsCollected.fulfill() }

        let dateBeforeAnyRequests = Date()

        // Given
        let session = URLSession.createServerMockURLSession(delegate: delegate)

        // When
        let taskWithURL = session.dataTask(with: URL.mockAny())
        taskWithURL.resume()

        let taskWithURLRequest = session.dataTask(with: URLRequest(url: .mockAny()))
        taskWithURLRequest.resume()

        // Then
        waitForExpectations(timeout: 0.5, handler: nil)
        _ = server.waitAndReturnRequests(count: 1)

        let dateAfterAllRequests = Date()
        XCTAssertTrue(interceptor.taskMetrics[0].session === session)
        XCTAssertTrue(interceptor.taskMetrics[0].task === taskWithURL)
        XCTAssertGreaterThan(interceptor.taskMetrics[0].metrics.taskInterval.start, dateBeforeAnyRequests)
        XCTAssertLessThan(interceptor.taskMetrics[0].metrics.taskInterval.end, dateAfterAllRequests)
        XCTAssertTrue(interceptor.tasksCompleted[0].session === session)
        XCTAssertTrue(interceptor.tasksCompleted[0].task === taskWithURL)
        XCTAssertEqual((interceptor.tasksCompleted[0].error! as NSError).localizedDescription, "some error")

        XCTAssertTrue(interceptor.taskMetrics[1].session === session)
        XCTAssertTrue(interceptor.taskMetrics[1].task === taskWithURLRequest)
        XCTAssertGreaterThan(interceptor.taskMetrics[1].metrics.taskInterval.start, dateBeforeAnyRequests)
        XCTAssertLessThan(interceptor.taskMetrics[1].metrics.taskInterval.end, dateAfterAllRequests)
        XCTAssertTrue(interceptor.tasksCompleted[1].session === session)
        XCTAssertTrue(interceptor.tasksCompleted[1].task === taskWithURLRequest)
        XCTAssertEqual((interceptor.tasksCompleted[1].error! as NSError).localizedDescription, "some error")
    }

    func testGivenURLSessionWithDatadogDelegate_whenTaskCompletesWithSuccess_itPassessAllValuesToTheInterceptor() throws {
        let notifyTaskCompleted = expectation(description: "Notify task completion")
        let notifyTaskMetricsCollected = expectation(description: "Notify task metrics collection")
        notifyTaskCompleted.expectedFulfillmentCount = 2
        notifyTaskMetricsCollected.expectedFulfillmentCount = 2

        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200), data: .mock(ofSize: 10)))

        interceptor.onTaskCompleted = { _, _, _ in notifyTaskCompleted.fulfill() }
        interceptor.onTaskMetricsCollected = { _, _, _ in notifyTaskMetricsCollected.fulfill() }

        let dateBeforeAnyRequests = Date()

        // Given
        let session = URLSession.createServerMockURLSession(delegate: delegate)

        // When
        let taskWithURL = session.dataTask(with: URL.mockAny())
        taskWithURL.resume()

        let taskWithURLRequest = session.dataTask(with: URLRequest(url: .mockAny()))
        taskWithURLRequest.resume()

        // Then
        waitForExpectations(timeout: 0.5, handler: nil)
        _ = server.waitAndReturnRequests(count: 1)

        let dateAfterAllRequests = Date()
        XCTAssertTrue(interceptor.taskMetrics[0].session === session)
        XCTAssertTrue(interceptor.taskMetrics[0].task === taskWithURL)
        XCTAssertGreaterThan(interceptor.taskMetrics[0].metrics.taskInterval.start, dateBeforeAnyRequests)
        XCTAssertLessThan(interceptor.taskMetrics[0].metrics.taskInterval.end, dateAfterAllRequests)
        XCTAssertTrue(interceptor.tasksCompleted[0].session === session)
        XCTAssertTrue(interceptor.tasksCompleted[0].task === taskWithURL)
        XCTAssertNil(interceptor.tasksCompleted[0].error)

        XCTAssertTrue(interceptor.taskMetrics[1].session === session)
        XCTAssertTrue(interceptor.taskMetrics[1].task === taskWithURLRequest)
        XCTAssertGreaterThan(interceptor.taskMetrics[1].metrics.taskInterval.start, dateBeforeAnyRequests)
        XCTAssertLessThan(interceptor.taskMetrics[1].metrics.taskInterval.end, dateAfterAllRequests)
        XCTAssertTrue(interceptor.tasksCompleted[1].session === session)
        XCTAssertTrue(interceptor.tasksCompleted[1].task === taskWithURLRequest)
        XCTAssertNil(interceptor.tasksCompleted[1].error)
    }

    // MARK: - Usage errors

    func testGivenFirstPartyHostsNotSet_whenInitializingDDURLSessionDelegate_itPrintsError() throws {
        let printFunction = PrintFunctionMock()
        consolePrint = printFunction.print
        defer { consolePrint = { print($0) } }

        // given
        Datadog.initialize(
            appContext: .mockAny(),
            configuration: Datadog.Configuration
                .builderUsing(clientToken: "abc.def", environment: "tests")
                .build()
        )
        XCTAssertNil(URLSessionAutoInstrumentation.instance)

        // when
        _ = DDURLSessionDelegate()

        // then
        XCTAssertEqual(
            printFunction.printedMessage,
            """
            🔥 Datadog SDK usage error: To use `DDURLSessionDelegate` you must specify first party hosts in `Datadog.Configuration` -
            use `track(firstPartyHosts:)` to define which requests should be tracked.
            """
        )

        try Datadog.deinitializeOrThrow()
    }
}
