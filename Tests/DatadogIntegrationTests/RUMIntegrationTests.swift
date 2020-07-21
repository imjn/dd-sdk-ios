/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import HTTPServerMock
import XCTest

class RUMIntegrationTests: IntegrationTests {
    private struct Constants {
        /// Time needed for data to be uploaded to mock server.
        static let dataDeliveryTime: TimeInterval = 30
    }

    func testLaunchTheAppNavigateThroughRUMFixtures() throws {
        // Server session recording RUM events send to `HTTPServerMock`.
        let rumServerSession = server.obtainUniqueRecordingSession()

        let app = ExampleApplication()
        app.launchWith(
            mockLogsEndpointURL: server.obtainUniqueRecordingSession().recordingURL,     // mock any
            mockTracesEndpointURL: server.obtainUniqueRecordingSession().recordingURL,   // mock any
            mockRUMEndpointURL: rumServerSession.recordingURL,
            mockSourceEndpointURL: server.obtainUniqueRecordingSession().recordingURL    // mock any 
        )
        let fixture1Screen = app.tapSendRUMEventsForUITests()
        let fixture2Screen = fixture1Screen.tapPushNextScreen()
        fixture2Screen.tapPushNextScreen()

        // Return desired count or timeout
        let recordedRUMRequests = try rumServerSession.pullRecordedPOSTRequests(
            count: 1,
            timeout: Constants.dataDeliveryTime
        )

        recordedRUMRequests.forEach { request in
            // Example path here: `/36882784-420B-494F-910D-CBAC5897A309/ui-tests-client-token?ddsource=ios&batch_time=1576404000000&ddtags=service:ui-tests-service-name,version:1.0,sdk_version:1.3.0-beta3,env:integration`
            let pathRegexp = #"^(.*)(\/ui-tests-client-token\?ddsource=ios&batch_time=)([0-9]+)(&ddtags=service:ui-tests-service-name,version:1.0,sdk_version:)([0-9].[0-9].[0-9](-[a-z0-9]*))(,env:integration)$"#
            XCTAssertNotNil(
                request.path.range(of: pathRegexp, options: .regularExpression, range: nil, locale: nil),
                "RUM request path: \(request.path) should match regexp: \(pathRegexp)"
            )
            XCTAssertTrue(request.httpHeaders.contains("Content-Type: text/plain;charset=UTF-8"))
        }

        // Assert RUM events
        let rumEventsMatchers = try recordedRUMRequests
            .flatMap { request in try RUMEventMatcher.fromNewlineSeparatedJSONObjectsData(request.httpBody) }

        // Assert `application_start` action
        let applicationStartAction: RUMActionEvent = try rumEventsMatchers[0].model()
        XCTAssertEqual(applicationStartAction.action.type, "application_start")

        // Assert Fixture 1 View updates
        let view1UpdateA: RUMViewEvent = try rumEventsMatchers[1].model()
        XCTAssertEqual(view1UpdateA.dd.documentVersion, 1)
        XCTAssertEqual(view1UpdateA.view.action.count, 1)

        let view1UpdateB: RUMViewEvent = try rumEventsMatchers[2].model()
        XCTAssertEqual(view1UpdateB.dd.documentVersion, 2)
        XCTAssertEqual(view1UpdateB.view.action.count, 1)

        // Assert Fixture 2 View updates
        let view2UpdateA: RUMViewEvent = try rumEventsMatchers[3].model()
        XCTAssertEqual(view2UpdateA.dd.documentVersion, 1)
        XCTAssertEqual(view2UpdateA.view.action.count, 0)

        let view2UpdateB: RUMViewEvent = try rumEventsMatchers[4].model()
        XCTAssertEqual(view2UpdateB.dd.documentVersion, 2)
        XCTAssertEqual(view2UpdateB.view.action.count, 0)

        // Assert Fixture 3 View updates
        let view3UpdateA: RUMViewEvent = try rumEventsMatchers[5].model()
        XCTAssertEqual(view3UpdateA.dd.documentVersion, 1)
        XCTAssertEqual(view3UpdateA.view.action.count, 0)
    }
}
