//
//  ViewController.swift
//  NSDiffableDataSourceSnapshot
//
//  Created by ryo.inomata on 2023/05/10.
//

import UIKit
import Alamofire

var articles: [QiitaArticle] = []

final class ViewController: UIViewController {
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Todo.ID>! = nil
//    private var repository: TodoRepository = .init()
    var token = "daac5dc84737855447811d2982becb4afb2d688d"
    private var per_page: Int = 20
    private var page: Int = 1
    
    private var viewArticles: [QiitaArticle] = []
    var isLoading = false
    enum LoadStatus {
        case initial
        case fetching
        case full
    }
    private var tag: String = "iOS"
    private var loadStatus: String = "initial"
    let decoder: JSONDecoder = JSONDecoder()
    let encoder: JSONEncoder = JSONEncoder()
    var todoIDs: [Todo.ID] { todos.map(\.id) }
    
//private var todos: [Todo] = []
    lazy private var todos: [Todo] = (1...30).map { i in
        Todo(id: UUID(), title: "test", done: false)
    }
    func todo(id: Todo.ID) -> Todo? {
        todos.first(where: { $0.id == id })
    }
    
    func update(cell: UITableViewCell, row: RowIdentifier) {
        cell.textLabel?.text = "Row \(row.id.row) in section \(row.id.section)"
    }
    
    //QiitaAPI制限を1時間1000回に増やす。ベアラー認証。
    let Auth_header: HTTPHeaders = [
        "Authorization" : "Bearer daac5dc84737855447811d2982becb4afb2d688d"
    ]
    enum Section {
        case main
    }
    override func viewDidAppear(_ animated: Bool) {
        getQiitaArticles()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        getQiitaArticles()
        configureCollectionView()
        configureDataSource()
        configureRefreshControl()
        applySnapshot()

    }
    
    private func configureCollectionView() {
        // collection view を初期化
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            let configuration = UICollectionLayoutListConfiguration(appearance: .plain)
            return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: layoutEnvironment)
        }
        collectionView = UICollectionView(frame: .null, collectionViewLayout: layout)
        
        // collection view を view の全面を覆う形で hierarchy に追加
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        collectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    private func configureDataSource() {
        let todoCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Todo> { cell, indexPath, todo in
            var configuration = cell.defaultContentConfiguration()
            configuration.text = todo.title
            cell.contentConfiguration = configuration
            
            cell.accessories = [
                .checkmark(displayed: .always, options: .init(isHidden: !todo.done))
            ]
        }
        dataSource = UICollectionViewDiffableDataSource(
            collectionView: collectionView, // DataSource と CollectionView の紐づけ
            cellProvider: { [weak self] collectionView, indexPath, todoID in // Cell を dequeue　して返却
                let todo = self?.todo(id: todoID)
//                let todo = self?.repository.todo(id: todoID)
                return collectionView.dequeueConfiguredReusableCell(using: todoCellRegistration, for: indexPath, item: todo)
            }
        )
    }
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Todo.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(todoIDs, toSection: .main)
//        snapshot.appendItems(repository.todoIDs, toSection: .main)
        
        dataSource.apply(snapshot, animatingDifferences: true)
    }
    private func getQiitaArticles() {
        guard loadStatus != "fetching" && loadStatus != "full" else { return }
        loadStatus = "fetching"
        AF.request("https://qiita.com/api/v2/tags/\(tag)/items?page=\(page)&per_page=\(per_page)",headers: Auth_header).responseData { [self] response in
            switch response.result {
            case .success:
                do {
                    print("page: " + String(self.page))
                    self.loadStatus = "loadmore"
                    viewArticles = try self.decoder.decode([QiitaArticle].self, from: response.data!)
                    
                    //                    self.delegate?.delegateKeyWord(articles: self.articles.count)
                    //                    for i in 0..<viewArticles.count {
                    //                        Diffable(id: UUID(), title: viewArticles[i].title)
                    //                        viewArticlesDiffable = Diffable
                    //                        print("Diffable", viewArticlesDiffable)
                    ////                        Diffable = viewArticles[i]
                    //                    }
                    //                    Diffable = viewArticles.title
                    //                    viewArticlesDiffable[title] = viewArticles[title]
                    if self.page == 100 {
                        self.loadStatus = "full"
                    }
                    articles += viewArticles
                    print("👺articles[0]", articles[0].title)
                    //                    print("👺articles", articles)
                    print("getQiitaArticles内且つdo内、サーチ処理中のpage ",self.page,"+ per_page " , self.per_page)
//                    self.page += 1 //pageを+1する処理
//                    todos = (1...30).map { i in
//                        Todo(id: UUID(), title: "test", done: false)
//                    }
                    print("todos", todos)
                    self.collectionView.reloadData()
                } catch {
                    self.loadStatus = "error"
                    print("デコードに失敗しました")
                }
            case .failure(let error):
                print("error", error)
            }
        }
    }
    typealias SamplePostTask = ([QiitaArticle]) -> Void
    
    func postUpdateKeyWordClosure(postTask: SamplePostTask) {
        let result = getQiitaArticles()
        postTask(articles)
    }
    func configureRefreshControl() {
        //RefreshControlを追加する処理
        collectionView.refreshControl = UIRefreshControl()
        collectionView.refreshControl?.addTarget(self, action: #selector(handleRefreshControl), for: .valueChanged)
    }
    @objc func handleRefreshControl() {
        articles = []
        self.page = 1
        getQiitaArticles()
        DispatchQueue.main.async {
            self.collectionView.reloadData()
            self.collectionView.refreshControl?.endRefreshing()
            self.view.endEditing(true)
        }
    }
}
//final class TodoRepository {
//    var articlesTodo = "test"
//    var todoIDs: [Todo.ID] { todos.map(\.id) }
//    private var todos: [Todo] = (1...3).map { i in
//    Todo(id: UUID(), title: "test", done: false)
//    }
//
//    func todo(id: Todo.ID) -> Todo? {
//        todos.first(where: { $0.id == id })
//    }
//    @objc func callGetKeyWord() {
//        let ViewController_ = ViewController()
//        ViewController_.postUpdateKeyWordClosure(postTask: {result in
//            self.articlesTodo = articles
//        })
//    }
//}

struct Todo: Identifiable {
    var id: UUID // Todo.ID が UUID のエイリアスになる
    var title: String
    var done: Bool
}
