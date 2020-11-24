//
//  DataSource.swift
//  ComplicatedDataStack
//
//  Created by Bill on 11/22/20.
//

import Foundation
import CoreData
import UIKit

final class DataSourceController: NSObject {
    let persistentContainer: NSPersistentContainer

    init(container: NSPersistentContainer) {
        self.persistentContainer = container
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(handleContextChangeNotification(_:)), name: .NSPersistentStoreRemoteChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRemoteChangeNotification(_:)), name: .NSPersistentStoreRemoteChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    lazy var fetchedResultsController: NSFetchedResultsController<Session> = {
        let request: NSFetchRequest<Session> = Session.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        request.returnsObjectsAsFaults = false
        request.fetchBatchSize = 32

        let frc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: persistentContainer.viewContext, sectionNameKeyPath: nil, cacheName: nil)

        return frc
    }()

    @objc
    private func handleContextChangeNotification(_ notification: Notification) {
        print(#function)
        dump(notification)
    }

    @objc
    private func handleRemoteChangeNotification(_ notification: Notification) {
        print(#function)
        dump(notification)
    }
}
