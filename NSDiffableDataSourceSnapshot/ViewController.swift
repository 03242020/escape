import UIKit
import Alamofire

struct Todo: Identifiable {
    var id: UUID
    var title: String
    var done: Bool
}
//2番目に読み込まれる
//final class TodoRepository {
//    func test() {
//        let ViewController_ = ViewController()
//        ViewController_.getQiitaArticles()
//    }
//    //30回for文回してる。30個の配列を用意している。
//    private var todos: [Todo] = (1...30).map { i in
//        Todo(id: UUID(), title: "Todo #\(i)", done: false)
//    }
//
//    //1-30の配列のid一覧(1-30)の作成
//    var todoIDs: [Todo.ID] { todos.map(\.id) }
//
//    //$0は雑に決めた引数名,今回はidを引数に入れて、最初に同じidがマッチしたらって動作
//    func todo(id: Todo.ID) -> Todo? {
//        todos.first(where: { $0.id == id })
//    }
//}

final class ViewController: UIViewController {
    enum Section {
        case main
    }
    var todoIDs: [Todo.ID] { todos.map(\.id) }
    func mutateTodoIDs() -> [Todo.ID] {
        var mutateTodoIDs: [Todo.ID] { todos.map(\.id) }
        return mutateTodoIDs
    }
    func todo(id: Todo.ID) -> Todo? {
        todos.first(where: { $0.id == id })
    }
    //使ってない。使いたいような。
    private var todos: [Todo] = []
    func mutateTodos() -> [Todo] {
        //　直列処理に変更
        var mutateTodos: [Todo] = []
        delayQiita(start: {
            getQiitaArticles()
        },completion: {
            mutateTodos = (1...articles.count).map { i in
                Todo(id: UUID(), title: "Todo #\(i)", done: false)
            }
        })
        return mutateTodos
    }
    func delayQiita(start:() -> Void, completion: () -> Void) {
        getQiitaArticles()
        completion()
    }
    func test() {
    }
    func todo(id: Todo.ID,todos: [Todo]) -> Todo? {
        todos.first(where: { $0.id == id })
    }

    
    //1番目に読み込まれる
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Todo.ID>!
    let decoder: JSONDecoder = JSONDecoder()
    let encoder: JSONEncoder = JSONEncoder()
    private var per_page: Int = 20
    private var tag: String = "iOS"
    var isLoading = false
    var testFinish:Int? = nil
    private var page: Int = 1
    //QiitaAPI制限を1時間1000回に増やす。ベアラー認証。
    let Auth_header: HTTPHeaders = [
        "Authorization" : "Bearer daac5dc84737855447811d2982becb4afb2d688d"
    ]
    private var articles: [QiitaArticle] = [QiitaArticle]() // ②取得した記事一覧を保持しておくプロパティ
    private var viewArticles: [QiitaArticle] = []
    //    必要以上のapi叩かない様にする
    private var loadStatus: String = "initial"
    enum LoadStatus {
        case initial
        case fetching
        case full
    }
//initのタイミングで30個の配列を生成
    //変数なのでやはり最短で呼ばれる
//    private var repository: TodoRepository?
//    private var repository: TodoRepository = .init()

    override func viewDidLoad() {
        //3番目に読み込まれる
        super.viewDidLoad()
        getQiitaArticles()
        wait( { return self.testFinish == nil } ) {
            // 取得しました
            print("finish")
        }
        configureCollectionView()
        configureDataSource()
        applySnapshot()
    }
    func getQiitaArticles() {
        guard loadStatus != "fetching" && loadStatus != "full" else { return }
        loadStatus = "fetching"
        print("getQiitaArticles内、サーチ処理中のpage ",self.page,"+ per_page " , self.per_page)
        DispatchQueue.main.async {
            AF.request("https://qiita.com/api/v2/tags/\(self.tag)/items?page=\(self.page)&per_page=\(self.per_page)",headers: self.Auth_header).responseData { [self] response in
                switch response.result {
                case .success:
                    do {
                        print("page: " + String(self.page))
                        self.loadStatus = "loadmore"
                        viewArticles = try self.decoder.decode([QiitaArticle].self, from: response.data!)
                        if self.page == 100 {
                            self.loadStatus = "full"
                        }
                        self.articles += viewArticles
//                        print("getQiitaArticleArticles",articles)
                        //                    print("getQiitaArticles内且つdo内、サーチ処理中のpage ",self.page,"+ per_page " , self.per_page)
                        self.page += 1 //pageを+1する処理
                        self.collectionView.reloadData()
                        self.testFinish = 1
                    } catch {
                        self.loadStatus = "error"
                        print("デコードに失敗しました")
                    }
                case .failure(let error):
                    print("error", error)
                }
            }
        }
    }
//4番目に読み込まれる
    private func configureCollectionView() {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            let configuration = UICollectionLayoutListConfiguration(appearance: .plain)
            return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: layoutEnvironment)
        }
        collectionView = UICollectionView(frame: .null, collectionViewLayout: layout)


        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        collectionView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
    
    /// 条件をクリアするまで待ちます
    ///
    /// - Parameters:
    ///   - waitContinuation: 待機条件
    ///   - compleation: 通過後の処理
    func wait(_ waitContinuation: @escaping (()->Bool), compleation: @escaping (()->Void)) {
        var wait = waitContinuation()
        // 0.01秒周期で待機条件をクリアするまで待ちます。
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            while wait {
                DispatchQueue.main.async {
                    wait = waitContinuation()
                    semaphore.signal()
                }
                semaphore.wait()
                Thread.sleep(forTimeInterval: 0.01)
            }
            // 待機条件をクリアしたので通過後の処理を行います。
            DispatchQueue.main.async {
                compleation()
            }
        }
    }


    private func configureDataSource() {
        let todoCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Todo> { cell, indexPath, todo in
            var configuration = cell.defaultContentConfiguration()
//            configuration.text = self.articles[0].title
            configuration.text = todo.title
            cell.contentConfiguration = configuration
            
 //ここの段階ではQiitaAPIの保存を利用できるがここだと20回叩かれる
            //タップ時のチェックマークと思われる
            cell.accessories = [
                .checkmark(displayed: .always, options: .init(isHidden: !todo.done))
            ]
        }
//5番目に読み込まれる
        dataSource = UICollectionViewDiffableDataSource(
            collectionView: collectionView,
            cellProvider: { [weak self] collectionView, indexPath, todoID in
                //repositoryの中のtodoを動かしている
//                func todo(id: Todo.ID) -> Todo? {
//                todos.first(where: { $0.id == id })
//            }
                //同一idを探すメソッドが呼ばれる
                //1か2番目
                let todo = self?.todo(id: todoID)
//                let todo = self?.repository.todo(id: todoID)
//                print(todo)
                return collectionView.dequeueConfiguredReusableCell(using: todoCellRegistration, for: indexPath, item: todo)
            }
        )
        

    }
//6番目に読み込まれる
    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Todo.ID>()
        snapshot.appendSections([.main])
        //強制アンラップを使用したので後ほど修正する
        //1か2番目に、2番目でないといけない
        snapshot.appendItems(mutateTodoIDs(), toSection: .main)
//        snapshot.appendItems(repository.todoIDs, toSection: .main)

        dataSource.apply(snapshot, animatingDifferences: true)
        print("👺articles: ", self.articles)
    }
}

extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}
