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

    func jiggle() {
        let jiggleLevel = Double.random(in: -1800..<1800)
        startAt?.addTimeInterval(jiggleLevel)
        endAt?.addTimeInterval(jiggleLevel)
    }
}
