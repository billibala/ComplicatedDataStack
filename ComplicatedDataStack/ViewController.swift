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
        DataSourceController(container: persistentContainer)
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
            cell.textLabel?.text = session.name
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

        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .play, target: self, action: #selector(handleJiggleItem(_:))),
            UIBarButtonItem(barButtonSystemItem: .pause, target: self, action: #selector(handleMakeBackgroundContextChange(_:))),
            UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(handleForegroundSave(_:)))
        ]
    }

    @IBAction func handleNewItem(_ sender: Any?) {
        let item = Session.newRandomSession(context: persistentContainer.viewContext)
        let going = SessionGoing.newRandomGoing(context: persistentContainer.viewContext)

        try! persistentContainer.viewContext.save()
    }

    @IBAction func handleJiggleItem(_ sender: Any?) {
        guard let selection = tableView.indexPathForSelectedRow else {
            return
        }
        dataController.fetchedResultsController.object(at: selection).jiggle()
    }

    @IBAction func handleMakeBackgroundContextChange(_ sender: Any?) {
        guard let selection = tableView.indexPathForSelectedRow else {
            return
        }
        let session = dataController.fetchedResultsController.object(at: selection)

        let background = persistentContainer.newBackgroundContext()
        background.name = "BackgroundEditor"
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

    @IBAction func handleForegroundSave(_ sender: Any?) {
        try! persistentContainer.viewContext.save()
    }
}

extension ViewController: NSFetchedResultsControllerDelegate {
    /**
     Check NSFetchedResultsController.h for more behavioral detail
     */
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        if tableView.numberOfSections == 0 {
            // no data in the table yet, so just apply
            myDataSource.apply(snapshot as NSDiffableDataSourceSnapshot<Int,NSManagedObjectID>, animatingDifferences: false)
        } else {
            var snapshot = snapshot as NSDiffableDataSourceSnapshot<Int,NSManagedObjectID>
            // Add the MOID to the "reloaded items" list so that view will refresh.
            snapshot.reloadItems(snapshot.itemIdentifiers)
            myDataSource.apply(snapshot, animatingDifferences: true)
        }
//        myDataSource.apply(snapshot as NSDiffableDataSourceSnapshot<Int,NSManagedObjectID>, animatingDifferences: tableView.numberOfSections != 0)
    }
}
