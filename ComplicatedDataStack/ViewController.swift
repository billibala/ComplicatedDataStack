//
//  ViewController.swift
//  ComplicatedDataStack
//
//  Created by Bill on 11/21/20.
//

import UIKit
import CoreData

extension UIViewController {
    var persistentContainer: NSPersistentContainer { (UIApplication.shared.delegate as! AppDelegate).persistentContainer }
}

class ViewController: UITableViewController {

    lazy var dataController: DataSourceController = {
        try! DataSourceController(container: persistentContainer)
    }()

    lazy var dateRangeFormatter: DateIntervalFormatter = {
        let fmt = DateIntervalFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt
    }()

    lazy var myDataSource: UITableViewDiffableDataSource<Int, NSManagedObjectID> = {
        UITableViewDiffableDataSource(tableView: self.tableView) { [unowned self] (table, indexPath, objectID) -> UITableViewCell? in
            let cell = table.dequeueReusableCell(withIdentifier: "default-cell") ?? {
                UITableViewCell(style: .subtitle, reuseIdentifier: "default-cell")
            }()
            let session = self.dataController.fetchedResultsController.managedObjectContext.registeredObject(for: objectID) as! Session

            if session.isDeleted {
                print("session deleted: \(session.objectID)")
                return cell
            }

            let idx = session.name!.firstIndex(of: "-") ?? session.name!.endIndex

            cell.textLabel?.text = "\(session.name![..<idx])-\(session.objectID.uriRepresentation().lastPathComponent)"
            if let start = session.startAt, let end = session.endAt {
                cell.detailTextLabel?.text = self.dateRangeFormatter.string(from: start, to: end)
            } else {
                cell.detailTextLabel?.text = nil
            }
            return cell
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(handleNewItem(_:)))

//        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "default-cell")

        tableView.dataSource = myDataSource
        dataController.fetchedResultsController.delegate = self
        try! dataController.fetchedResultsController.performFetch()

        let btn = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(handleBackgroundDelete(_:)))
        btn.tintColor = UIColor.green

        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .play, target: self, action: #selector(handleResetContext(_:))),
            UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(handleForegroundSave(_:))),
            UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(handleRefreshFRC(_:))),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(handleRefreshObjects(_:))),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(handleAdvanceAndRefreshObjects(_:))),
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(handleBatchInsert(_:))),
            UIBarButtonItem(barButtonSystemItem: .pause, target: self, action: #selector(handleBatchChange(_:))),
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(handleBatchDelete(_:))),
            btn
        ]
    }

    @IBAction func handleRefreshFRC(_ sender: Any?) {
        print("L\(#line) reset FRC")
        dataController.resetFRC()
        dataController.fetchedResultsController.delegate = self
        try! dataController.fetchedResultsController.performFetch()
        tableView.reloadData()
    }

    @IBAction func handleNewItem(_ sender: Any?) {
        print("L\(#line) Add new item to `view context`")
        let item = Session.newRandomSession(context: persistentContainer.viewContext)
        let going = SessionGoing.newRandomGoing(context: persistentContainer.viewContext)

        try! persistentContainer.viewContext.save()
    }

    @IBAction func handleResetContext(_ sender: Any?) {
        print("reset `view context`")
        persistentContainer.viewContext.reset()
    }

    @IBAction func handleJiggleItem(_ sender: Any?) {
        guard let selection = tableView.indexPathForSelectedRow else {
            return
        }
        print("L\(#line) jiggle selected item in `view context`")
        dataController.fetchedResultsController.object(at: selection).jiggle()
    }

    @IBAction func handleRefreshObjects(_ sender: Any?) {
        print("L\(#line) viewContext.refreshAllObjects()")
//        dump(persistentContainer.viewContext.queryGenerationToken)
        persistentContainer.viewContext.refreshAllObjects()
    }

    @IBAction func handleAdvanceAndRefreshObjects(_ sender: Any?) {
        /**
         The pattern here does not work for objects inserted from batch insert.

         Those objects are NEW. `refreshAllObjects` only refreshes objects currently registered with the context. That means, in practice, FRC will only get "updates" and "deletes" events.

         If you call `mergeChanges(fromContextDidSave:)` on the context, the behavior is slightly different. "updates", "deletes" and "inserts" are all merge.

         This behavior, while understandable, requires developer to pay extra attention.
         */
        print("L\(#line) advance to current generation. And call viewContext.refreshAllObjects()")
        try! persistentContainer.viewContext.setQueryGenerationFrom(.current)
        persistentContainer.viewContext.refreshAllObjects()
    }

    @IBAction func handleMakeBackgroundContextChange(_ sender: Any?) {
        guard let selection = tableView.indexPathForSelectedRow else {
            return
        }
        print("L\(#line) jiggle selected item in `background context` and save()")
        let session = dataController.fetchedResultsController.object(at: selection)

        let background = dataController.backgroundContext
        background.performAndWait {
            guard let mySession = try? background.existingObject(with: session.objectID) as? Session else {
                return
            }
            mySession.jiggle()
            background.transactionAuthor = "jiggler"
            try! background.save()
            background.transactionAuthor = nil
        }
    }

    @IBAction func handleBatchChange(_ sender: Any?) {
        guard let selection = tableView.indexPathForSelectedRow else {
            return
        }
        print("L\(#line) batch jiggle selected item")
        let session = dataController.fetchedResultsController.object(at: selection)
        let serverID = session.serverID!

        print("object to update: \(session.objectID) \(serverID)")

        let background = dataController.backgroundContext
        background.perform {
            background.batchUpdate(uniqueID: serverID)
        }
    }

    @IBAction func handleBackgroundDelete(_ sender: Any?) {
        guard let selection = tableView.indexPathForSelectedRow else {
            return
        }
        print("L\(#line) background delete selected item")
        let session = dataController.fetchedResultsController.object(at: selection)

        let background = dataController.backgroundContext
        background.performAndWait {
            guard let mySession = try? background.existingObject(with: session.objectID) as? Session else {
                return
            }
            background.delete(mySession)
            background.transactionAuthor = "delete"
            try! background.save()
            background.transactionAuthor = nil
        }
    }

    @IBAction func handleBatchDelete(_ sender: Any?) {
        guard let selection = tableView.indexPathForSelectedRow else {
            return
        }
        print("L\(#line) batch delete selected item")
        let session = dataController.fetchedResultsController.object(at: selection)

        let background = persistentContainer.newBackgroundContext()
        background.perform {
            background.batchDelete(objectIDs: [session.objectID])
        }
//        let background = dataController.backgroundContext
//        background.performAndWait {
//            guard let mySession = try? background.existingObject(with: session.objectID) as? Session else {
//                return
//            }
//
//            background.delete(mySession)
//            background.transactionAuthor = "delete"
//            try! background.save()
//            background.transactionAuthor = nil
//        }
    }

    @IBAction func handleForegroundSave(_ sender: Any?) {
        print("L\(#line) save `view context`")
        try! persistentContainer.viewContext.save()
    }

    @IBAction func handleBatchInsert(_ sender: Any?) {
        print("L\(#line) batch insert")
        Session.batchInsert(context: dataController.backgroundContext)
    }
}

extension ViewController: NSFetchedResultsControllerDelegate {
    /**
     Check NSFetchedResultsController.h for more behavioral detail
     */
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        print("FRC snapshot did change delegate method")
        if tableView.numberOfSections == 0 {
            // no data in the table yet, so just apply
            myDataSource.apply(snapshot as NSDiffableDataSourceSnapshot<Int,NSManagedObjectID>, animatingDifferences: false)
        } else {
//            var snapshot = snapshot as NSDiffableDataSourceSnapshot<Int,NSManagedObjectID>
            // Add the MOID to the "reloaded items" list so that view will refresh.
//            snapshot.reloadItems(snapshot.itemIdentifiers)
            myDataSource.apply(snapshot as! NSDiffableDataSourceSnapshot<Int,NSManagedObjectID>, animatingDifferences: true)
        }
//        myDataSource.apply(snapshot as NSDiffableDataSourceSnapshot<Int,NSManagedObjectID>, animatingDifferences: tableView.numberOfSections != 0)
    }
}
