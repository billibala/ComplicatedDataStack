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
    /**
     There are many tools available to identify a transaction in PHT. E.g. NSPersistentHistoryTransaction object has `bundleID` property where we can identify which extension actually made the change.
     */
    private let appBackgroundContextName = "MainAppBackgroundEditor"
    let persistentContainer: NSPersistentContainer
    private(set) var lastToken: NSPersistentHistoryToken? = nil
    lazy var backgroundContext: NSManagedObjectContext = {
        let context = persistentContainer.newBackgroundContext()
        context.name = appBackgroundContextName
//        try! context.setQueryGenerationFrom(.current)
        return context
    }()

    init(container: NSPersistentContainer) {
        self.persistentContainer = container
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(self.handleContextChangeNotification(_:)), name: .NSManagedObjectContextDidSave, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRemoteChangeNotification(_:)), name: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var fetchedResultsController: NSFetchedResultsController<Session> {
        if let frc = _frc {
            return frc
        }

        let request: NSFetchRequest<Session> = Session.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        request.returnsObjectsAsFaults = false
        request.fetchBatchSize = 32

        let frc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: persistentContainer.viewContext, sectionNameKeyPath: nil, cacheName: nil)

        _frc = frc

        return frc
    }

    private var _frc: NSFetchedResultsController<Session>? = nil

    func resetFRC() {
        _frc = nil
    }

    @objc
    private func handleContextChangeNotification(_ notification: Notification) {
        print("L\(#line) \(#function)")
        guard let infoDict = notification.userInfo as? [String:Any], let objMOC = notification.object as? NSManagedObjectContext else {
            return
        }

        print("main thread? \(Thread.isMainThread)")
        infoDict.forEach { kvPair in
            let (keyStr, value) = kvPair
            guard let key = NSManagedObjectContext.NotificationKey(rawValue: keyStr) else {
                return
            }
            switch key {
            case .insertedObjects:
                print("inserted")
                if let items = value as? Set<NSManagedObject> {
                    print("insert: \(items.count)")
                }
            case .updatedObjects:
                print("updated")
                if let items = value as? Set<NSManagedObject> {
                    print("updated: \(items.count)")
                }
            case .deletedObjects:
                /**
                 Decide if we can call "refresh all objects" on the view context.

                 If the deleted object is currently the main subject of a detail view, we cannot advance the store generation until that view is unwound.
                 */
                print("deleted")
                if let items = value as? Set<NSManagedObject> {
                    print("deleted: \(items.count)")
                }
            default:
//                assertionFailure()
                print(key.rawValue)
                dump(value)
                break
            }
        }

//        persistentContainer.viewContext.mergeChanges(fromContextDidSave: notification)
    }

    @objc
    private func handleRemoteChangeNotification(_ notification: Notification) {
        print("L\(#line) \(#function)")
        /**
         NSPersistentStoreRemoteChangeNotification's UserInfo contain 2 keys:
         * NSPersistentStoreURLKey - Store key isn't used in this case since we only have 1 store.
         * NSPersistentHistoryTokenKey
         */
        guard let historyToken = notification.userInfo?[NSPersistentHistoryTokenKey] as? NSPersistentHistoryToken else {
            assertionFailure()
            return
        }
//        dump(historyToken)
        // with `historyToken`, we can dig up detail of this transaction.
        // for development purpose, where we don't have proper implemenetation to purge old log, we just examine the transaction which triggers this notification handler.

        let background = self.persistentContainer.newBackgroundContext()
        // We just need the "history token" key cos we only have one persistent store
        // What is "history"? What is "transaction"?
        // Exploring fetch requests
        background.perform {
            self.processHistory(historyToken, context: background)
        }
    }

    func processHistory(_ historyToken: NSPersistentHistoryToken, context background: NSManagedObjectContext) {
        return
//            let transactionRequest = NSPersistentHistoryTransaction.fetchRequest!
//            transactionRequest.predicate = NSPredicate(format: "contextName = %@", appBackgroundContextName)
//            transactionRequest.predicate = NSPredicate(format: "token = %@", historyToken)
        // We can't fetch directly from NSPersistentHistoryTransaction fetch request.
        // Core Data throws runtime error
//            let transactionResult = try! background.execute(transactionRequest)
//            dump(transactionResult)

        let token: NSPersistentHistoryToken? = nil

        let changeRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: token)
//            changeRequest.fetchRequest = transactionRequest
        changeRequest.resultType = .transactionsAndChanges
        guard let changeResult = try! background.execute(changeRequest) as? NSPersistentHistoryResult, let theHistory = changeResult.result as? [NSPersistentHistoryTransaction] else {
            assertionFailure()
            return
        }

        /**
         Fetching and transversing the result uses extra resources.

         It is cheaper to process the "context did save" notification user info becuase it does not involve fetching logs from persistent history.

         In our case, batch operations bypass managed object contexts and persistent store coordinator. So, we need to process "remote change notificaiton"

         Besides needed more processing resources, the major drawback is... we need to purge persistent history. Each process also needs to keep track of the token it last read.
         */
        print("number of items: \(theHistory.count)")
        theHistory.filter {
            dump($0.token)
            guard $0.token == historyToken else {
                return false
            }
            $0.changes?.forEach { theChange in
                switch theChange.changeType {
                case .insert:
                    print("new item: \(theChange)")
                case .update:
                    print("item updated: \(theChange.changedObjectID) \(theChange.updatedProperties)")
                case .delete:
                    // Read the tombstone to see if the entity is interested to view.
                    print("item deleted: \(theChange.changedObjectID) \(theChange.tombstone)")
                @unknown default:
                    fatalError()
                }
            }
            return true
        }.forEach { _ in
            // Changes is merged and store generation is advanced on the calling context
            /**
             Calling `merge` will advance store generation.

             Do not call merge on view context if we want view updates to be delayed.
             */
//            self.persistentContainer.viewContext.mergeChanges(fromContextDidSave: $0.objectIDNotification())
//            background.mergeChanges(fromContextDidSave: $0.objectIDNotification())
        }
    }
}
