//
//  SessionGoing+CoreDataClass.swift
//  ComplicatedDataStack
//
//  Created by Bill on 11/23/20.
//
//

import Foundation
import CoreData

@objc(SessionGoing)
public class SessionGoing: NSManagedObject {
    static func newRandomGoing(context: NSManagedObjectContext) -> SessionGoing {
        let theSession = SessionGoing(context: context)
        theSession.sessionID = UUID().uuidString
        theSession.reservationStatus = "reserved"

        return theSession
    }

    static func batchInsert(context: NSManagedObjectContext) {
        let request = NSBatchInsertRequest(entity: Self.entity(), managedObjectHandler: {
            let going = $0 as! SessionGoing
            going.sessionID = UUID().uuidString
            going.reservationStatus = "reserved"

            return true
        })

        let insertStatus = try! context.execute(request)
        dump(insertStatus)
    }
}
