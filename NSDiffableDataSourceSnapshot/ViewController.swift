import UIKit
import Alamofire

struct Todo: Identifiable {
    var id: UUID
    var title: String
    var done: Bool
}

final class ViewController: UIViewController {
    enum Section {
        case main
    }
    //変数なのでやはり最短で呼ばれる
    //1番目に読み込まれる
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, Todo.ID>!
    let decoder: JSONDecoder = JSONDecoder()
    let encoder: JSONEncoder = JSONEncoder()
    private var per_page: Int = 5
    private var tag: String = "iOS"
    var isLoading = false
    var testFinish:Int? = nil
    var testFinish2:Int? = nil
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
    var margedTodos: [Todo] = [Todo]()
    //articles分のfor文回してる。30個の配列を用意している。
    func marge() {
        var todos: [Todo] = (1...articles.count).map { i in
            Todo(id: UUID(), title: articles[i-1].title, done: false)
//            Todo(id: UUID(), title: "Todo #\(i)", done: false)
        }
        self.margedTodos = todos
        self.testFinish2 = 1
    }

    override func viewDidLoad() {
        //3番目に読み込まれる
        super.viewDidLoad()
        getQiitaArticles()
        wait( { return self.testFinish == nil } ) {
            // 取得しました
            print("finish")
            self.marge()
  
        }
        wait( { return self.testFinish2 == nil } ) {
            self.configureCollectionView()
            self.configureDataSource()
            self.applySnapshot()
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
    private func configureDataSource() {
        //todoどこで紐づけられてるのか
        let todoCellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Todo> { cell, indexPath, margedTodos in
            var configuration = cell.defaultContentConfiguration()
//            configuration.text = "ああ"
//            configuration.text = todo.title
            configuration.text = margedTodos.title
            cell.contentConfiguration = configuration
            
 //ここの段階ではQiitaAPIの保存を利用できるがここだと20回叩かれる
            //タップ時のチェックマークと思われる
            cell.accessories = [
//              .checkmark(displayed: .always, options: .init(isHidden: todo.done))
                .checkmark(displayed: .always, options: .init(isHidden: false))
            ]
        }
//5番目に読み込まれる
        dataSource = UICollectionViewDiffableDataSource(
            collectionView: collectionView,
            cellProvider: { [weak self] collectionView, indexPath, todoID in
                //同一idを探すメソッドが呼ばれる
                //1か2番目
                let margedTodos = self?.mutateTodo(id: todoID)
//                let todo = self?.repository.todo(id: todoID)
                return collectionView.dequeueConfiguredReusableCell(using: todoCellRegistration, for: indexPath, item: margedTodos)
            })
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
            print("👺articles: ", articles)
        }
    private func mutateTodoIDs() -> [Todo.ID] {
        var mutateTodoIDs: [Todo.ID] { margedTodos.map(\.id) }
        return mutateTodoIDs
    }
    private func mutateTodo(id: Todo.ID) -> Todo? {
        margedTodos.first(where: { $0.id == id })
    }
    private func getQiitaArticles() {
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
                        articles += viewArticles
                        self.page += 1 //pageを+1する処理
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
    /// 条件をクリアするまで待ちます
    ///
    /// - Parameters:
    ///   - waitContinuation: 待機条件
    ///   - compleation: 通過後の処理
    private func wait(_ waitContinuation: @escaping (()->Bool), compleation: @escaping (()->Void)) {
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
}

extension ViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}
