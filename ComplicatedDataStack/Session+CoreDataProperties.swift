//
//  Session+CoreDataProperties.swift
//  ComplicatedDataStack
//
//  Created by Bill on 11/21/20.
//
//

import Foundation
import CoreData


extension Session {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Session> {
        return NSFetchRequest<Session>(entityName: "Session")
    }

    @NSManaged public var serverID: String?
    @NSManaged public var name: String?
    @NSManaged public var startAt: Date?
    @NSManaged public var endAt: Date?

}

extension Session : Identifiable {

}
