//
// ADOBE CONFIDENTIAL
//
// Copyright 2020 Adobe
// All Rights Reserved.
//
// NOTICE: All information contained herein is, and remains
// the property of Adobe and its suppliers, if any. The intellectual
// and technical concepts contained herein are proprietary to Adobe
// and its suppliers and are protected by all applicable intellectual
// property laws, including trade secret and copyright laws.
// Dissemination of this information or reproduction of this material
// is strictly forbidden unless prior written permission is obtained
// from Adobe.
//


import Foundation
import ACPCore

class RequestBuilder {
    private let TAG = "RequestBuilder"
    
    /// Control charactor used before each response fragment. Response streaming is enabled when both `recoredSeparator` and `lineFeed` are non nil.
    var recordSeparator: String?
    
    /// Control character used at the end of each response fragment. Response streaming is enabled when both `recoredSeparator` and `lineFeed` are non nil.
    var lineFeed: String?
    
    /// The Experience Cloud Organization ID to be sent with this request
    var organizationId: String?
    
    /// The Experiece Cloud ID to be sent with this request
    var experienceCloudId: String?
    
    // TODO add system info service and data store as parameters
    init() {
    }
    
    func getPayload(_ events: [ACPExtensionEvent]) -> Data? {
        if (events.isEmpty) {
            return nil
        }
        
        let streamingMetadata = Streaming(recordSeparator: recordSeparator, lineFeed: lineFeed)
        let konductorConfig = KonductorConfig(imsOrgId: organizationId, streaming: streamingMetadata)
        // TODO add state store to request metadata
        let requestMetadata = RequestMetadata(konductorConfig: konductorConfig)
        
        var request = EdgeRequest(meta: requestMetadata)
        request.events = extractPlatformEvents(events)
        
        // set ECID if available
        if let ecid = experienceCloudId {
            var identityMap = IdentityMap()
            identityMap.addItem(namespace: "ECID", id: ecid)
            request.xdm = RequestContext(identityMap: identityMap)
        }
        
        let encoder = JSONEncoder()
        
        do {
            // TODO return EdgeRequest here instead of encoded JSON Data?
            return try encoder.encode(request)
        } catch {
            ACPCore.log(ACPMobileLogLevel.warning, tag: TAG, message: "Failed to encode request to JSON with error '\(error)'")
        }
        
        return nil
    }
    
    private func extractPlatformEvents(_ events: [ACPExtensionEvent]) -> [ [AnyHashable : AnyCodable] ] {
        var platformEvents: [[AnyHashable:AnyCodable]] = []
        
        for event in events {
            guard var eventData = event.eventData else {
                continue
            }
            
            if eventData["xdm"] == nil {
                eventData["xdm"] = [:]
            }
            
            if var xdm = eventData["xdm"] as? [String : Any] {
                let date = Date(timeIntervalSince1970: TimeInterval(event.eventTimestamp/1000))
                xdm["timestamp"] = ISO8601DateFormatter().string(from: date)
                xdm["eventId"] = event.eventUniqueIdentifier
                eventData["xdm"] = xdm
            }
            
            platformEvents.append(AnyCodable.from(dictionary: eventData))
            
        }
        
        return platformEvents
    }
    
}
