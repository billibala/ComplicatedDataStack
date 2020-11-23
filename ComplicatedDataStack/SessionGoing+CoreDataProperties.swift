//
//  SessionGoing+CoreDataProperties.swift
//  ComplicatedDataStack
//
//  Created by Bill on 11/23/20.
//
//

import Foundation
import CoreData


extension SessionGoing {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SessionGoing> {
        return NSFetchRequest<SessionGoing>(entityName: "SessionGoing")
    }

    @NSManaged public var sessionID: String?
    @NSManaged public var reservationStatus: String?

}

extension SessionGoing : Identifiable {

}
