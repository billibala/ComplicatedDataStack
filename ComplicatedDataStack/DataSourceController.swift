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
    private(set) var lastToken: NSPersistentHistoryToken? = nil

    init(container: NSPersistentContainer) {
        self.persistentContainer = container
        super.init()

//        NotificationCenter.default.addObserver(self, selector: #selector(handleContextChangeNotification(_:)), name: .NSManagedObjectContextDidSave, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRemoteChangeNotification(_:)), name: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator)
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

//    @objc
//    private func handleContextChangeNotification(_ notification: Notification) {
//        print(#function)
//    }

    @objc
    private func handleRemoteChangeNotification(_ notification: Notification) {
        print(#function)
        dump(notification)
        /**
         NSPersistentStoreRemoteChangeNotification's UserInfo contain 2 keys:
         * NSPersistentStoreURLKey
         * NSPersistentHistoryTokenKey
         */
        guard let historyToken = notification.userInfo?[NSPersistentHistoryTokenKey] as? NSPersistentHistoryToken else {
            assertionFailure()
            return
        }

        let background = persistentContainer.newBackgroundContext()
        // We just need the "history token" key cos we only have one persistent store
        // What is "history"? What is "transaction"?
        // Exploring fetch requests
        background.performAndWait {
            let transactionRequest = NSPersistentHistoryTransaction.fetchRequest!
            transactionRequest.predicate = NSPredicate(format: "contextName = %@", "BackgroundEditor")
            // We can't fetch directly from NSPersistentHistoryTransaction fetch request.
            // Core Data throws runtime error
//            let transactionResult = try! background.execute(transactionRequest)
//            dump(transactionResult)

            let token: NSPersistentHistoryToken? = nil

            let changeRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: token)
            changeRequest.fetchRequest = transactionRequest
            changeRequest.resultType = .transactionsAndChanges
            guard let changeResult = try! background.execute(changeRequest) as? NSPersistentHistoryResult, let theHistory = changeResult.result as? [NSPersistentHistoryTransaction] else {
                assertionFailure()
                return
            }

            /**
             Fetching and transversing the result uses memory.

             It is cheaper to process the "context did save" notification user info becuase it does not involve a database fetch.

             In our case, we don't have out-of-process change. So, we can consider processing solely "context did save" notification.

             Major advantage of this approach is... we don't need to manage PHT records. We don't have to enable PHT and we don't have to write code to purge old history.

             Another lense is...

             We can ignore initial import. Just name the transaction author as "initial import".
             */
            theHistory.forEach { (transaction) in
                transaction.changes?.forEach { theChange in
                    switch theChange.changeType {
                    case .insert:
                        print("new item: \(theChange)")
                    case .update:
                        print("item updated: \(theChange.changedObjectID) \(theChange.updatedProperties)")
                    case .delete:
                        print("item deleted: \(theChange.changedObjectID) \(theChange.tombstone)")
                    @unknown default:
                        fatalError()
                    }
                }
            }

        }
    }
}
