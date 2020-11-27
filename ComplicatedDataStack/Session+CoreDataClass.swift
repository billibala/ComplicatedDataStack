//
//  Session+CoreDataClass.swift
//  ComplicatedDataStack
//
//  Created by Bill on 11/21/20.
//
//

import Foundation
import CoreData

@objc(Session)
public class Session: NSManagedObject {
    static func newRandomSession(context: NSManagedObjectContext) -> Session {
        let theSession = Session(context: context)
        theSession.name = UUID().uuidString
        let startDate = Date(timeIntervalSinceNow: Double.random(in: -3600..<3600))
        let endDate = startDate.addingTimeInterval(Double.random(in: 0..<3600*3))
        theSession.startAt = startDate
        theSession.endAt = endDate
        theSession.serverID = UUID().uuidString

        return theSession
    }

    static func batchInsert(context: NSManagedObjectContext) {
        context.performAndWait {
            var loopIdx = 0
            let request = NSBatchInsertRequest(entity: Self.entity(), managedObjectHandler: {
                guard loopIdx < 1 else {
                    return true
                }

                let theSession = $0 as! Session
                theSession.name = UUID().uuidString
                let startDate = Date(timeIntervalSinceNow: Double.random(in: -3600..<3600))
                let endDate = startDate.addingTimeInterval(Double.random(in: 0..<3600*3))
                theSession.startAt = startDate
                theSession.endAt = endDate
                theSession.serverID = UUID().uuidString

                loopIdx += 1

                return false
            })
//            request.resultType = .objectIDs

//            let insertStatus = (try! context.execute(request)) as! NSBatchInsertResult
            _ = try! context.execute(request)
        }
    }

    func jiggle() {
        let jiggleLevel = Double.random(in: -1800..<1800)
        startAt?.addTimeInterval(jiggleLevel)
        endAt?.addTimeInterval(jiggleLevel)
    }
}

extension NSManagedObjectContext {
    func batchDelete(objectIDs: [NSManagedObjectID]) {
        print(#function)
        let request = NSBatchDeleteRequest(objectIDs: objectIDs)
        request.resultType = .resultTypeStatusOnly
        let result = try! execute(request) as! NSBatchDeleteResult
        dump(result.result as! NSNumber)
    }
}
