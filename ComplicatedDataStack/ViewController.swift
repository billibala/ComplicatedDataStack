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

    lazy var myDataSource: UITableViewDiffableDataSource<String, NSManagedObjectID> = {
        UITableViewDiffableDataSource(tableView: self.tableView) { [unowned self] (table, indexPath, objectID) -> UITableViewCell? in
            let cell = table.dequeueReusableCell(withIdentifier: "default-cell", for: indexPath)
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

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "default-cell")

        tableView.dataSource = myDataSource
        dataController.fetchedResultsController.delegate = self
        try! dataController.fetchedResultsController.performFetch()
    }

    @IBAction func handleNewItem(_ sender: Any?) {
        let item = Session.newRandomSession(context: persistentContainer.viewContext)
        let going = SessionGoing.newRandomGoing(context: persistentContainer.viewContext)
        print("new item: \(item)")
        print("going: \(going)")
        try! persistentContainer.viewContext.save()
    }
}

extension ViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        myDataSource.apply(snapshot as NSDiffableDataSourceSnapshot<String,NSManagedObjectID>, animatingDifferences: tableView.numberOfSections != 0)
    }
}
