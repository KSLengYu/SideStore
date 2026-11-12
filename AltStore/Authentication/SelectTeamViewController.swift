//
//  SelectTeamViewController.swift
//  AltStore
//
//  Created by Megarushing on 4/26/21.
//  Copyright © 2021 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import SideSign

final class SelectTeamViewController: UITableViewController
{
    public var teams: [ALTTeam]?
    public var completionHandler: ((Result<ALTTeam, Swift.Error>)  -> Void)?
    
    private var prototypeHeaderFooterView: SettingsHeaderFooterView!
    
    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    #endif
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("Select a Team", comment: "")
        self.navigationItem.title = NSLocalizedString("Select a Team", comment: "")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return teams?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        return self.completionHandler!(.success((self.teams?[indexPath.row])!))
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TeamCell", for: indexPath) as! InsetGroupTableViewCell

        cell.textLabel?.text = self.teams?[indexPath.row].name
        if let typeDesc = self.teams?[indexPath.row].type.localizedDescription {
            cell.detailTextLabel?.text = NSLocalizedString(typeDesc, comment: "")
        }
        let count = self.teams?.count ?? 0
        if count <= 1 {
            cell.style = InsetGroupTableViewCell.Style.single
        } else if indexPath.row == 0 {
            cell.style = InsetGroupTableViewCell.Style.top
        } else if indexPath.row == count - 1 {
            cell.style = InsetGroupTableViewCell.Style.bottom
        } else {
            cell.style = InsetGroupTableViewCell.Style.middle
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        NSLocalizedString("Teams", comment: "")
    }
    
}
