import SwiftUI
import AudioToolbox

enum Piece: Equatable {
    case empty                       // 空，还没下子的
    case black                       // 黑棋子
    case white                       // 白棋子
    
    var opposite: Piece {            // 对手
        switch self {
        case .black: return .white
        case .white: return .black
        case .empty: return .empty
        }
    }
}

// MARK: - Model
class ReversiGame: ObservableObject {
    @Published var board: [[Piece]]                     // 棋盘
    @Published var currentPlayer: Piece = .black        // 当前玩家
    @Published var gameOver = false                     // 游戏结束
    @Published var emptyCells = 0                       // 空格子数
    @Published var blackScore = 0                       // 黑方分数（棋子数）
    @Published var whiteScore = 0                       // 白方分数（棋子数）
    
    init() {
        board = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        board[3][3] = .white
        board[3][4] = .black
        board[4][3] = .black
        board[4][4] = .white
        updateScores()
    }
    
    // 更新分数
    func updateScores() {
        emptyCells = board.flatMap { $0 }.filter { $0 == .empty }.count    // 更新空格子数
        blackScore = board.flatMap { $0 }.filter { $0 == .black }.count    // 更新黑方分数
        whiteScore = board.flatMap { $0 }.filter { $0 == .white }.count    // 更新白方分数
    }
    
    // 指定点是否在棋盘内
    func isWithinBounds(row: Int, col: Int) -> Bool {
        return row >= 0 && row < 8 && col >= 0 && col < 8
    }
    
    // 是否合法的落子
    func isValidDrop(row: Int, col: Int, player: Piece) -> Bool {
        // 空格才能下
        guard board[row][col] == .empty else { return false }
        
        // 对手
        let opponent = player.opposite
        // 8个方向
        let directions = [(-1, -1), (-1, 0), (-1, 1),
                          ( 0, -1),          ( 0, 1),
                          ( 1, -1),  (1, 0), ( 1, 1)]
        
        // 逐个方向进行判断
        for direction in directions {
            var x = row + direction.0
            var y = col + direction.1
            var foundOpponent = false
            
            while isWithinBounds(row: x, col: y) {
                let cell = board[x][y]
                if cell == opponent {
                    // 如果发现对手，就做标记，继续沿着同一个方向找下一个进行判断
                    foundOpponent = true
                } else if cell == player {
                    // 如果找到自己之前找到对手，说明这个方向可以，直接
                    if foundOpponent { return true }
                    // 否则 这个方向不行 结束这个方向的判断，继续下一个方向
                    break
                } else {
                    // 如果是空白 这个方向不行 结束这个方向的判断，继续下一个方向
                    break
                }
                x += direction.0
                y += direction.1
            }
        }
        return false
    }
    
    // 落1个子
    func dropOnePiece(row: Int, col: Int) {
        guard isValidDrop(row: row, col: col, player: currentPlayer) else { return }   // 如果不合法，不能在这里落子
        
        board[row][col] = currentPlayer // 下子
        AudioServicesPlaySystemSound(1001) // 音效

        let opponent = currentPlayer.opposite
        let directions = [(-1, -1), (-1, 0), (-1, 1),
                          ( 0, -1),          ( 0, 1),
                          ( 1, -1),  (1, 0), ( 1, 1)]
        
        // 逐个方向看看有没有可以吃的棋子，有就吃掉它
        for direction in directions {
            var x = row + direction.0
            var y = col + direction.1
            // 用个数组来记录这个方向上紧挨着的对手棋子，有可能可以吃
            var adjacentCellsOfOpponentInOneDirection = [(Int, Int)]()
            
            while isWithinBounds(row: x, col: y) && board[x][y] == opponent {
                // 发现一个就把位置加入到临时数组，再沿着这个方向找下一个，直到不是对手的子
                adjacentCellsOfOpponentInOneDirection.append((x, y))
                x += direction.0
                y += direction.1
            }
            
            // 不是对手的子，有2中情况，自己的子或空白未下的
            if isWithinBounds(row: x, col: y) && board[x][y] == currentPlayer {
                // 全部吃掉 TODO: 这里要不要判断数组是否为空？数组为空的情况是第一颗紧挨着的是自己的子
                for (i, j) in adjacentCellsOfOpponentInOneDirection {
                    board[i][j] = currentPlayer
                }
            }
        }
        
        // 更新分数
        updateScores()
        // 轮到下一个玩家
        currentPlayer = currentPlayer.opposite
        
        // 看看这个玩家能不能下子，如果不能下子有2种情况，1没有可以下的子，就跳过，2下满了，就结束游戏
        // 这个优化流程：当你不能下，我也不能下，就结束，好处在于不用判断是否下满，减少代码量
        if !hasAnyValidMove(for: currentPlayer) {
            currentPlayer = currentPlayer.opposite
            if !hasAnyValidMove(for: currentPlayer) {
                gameOver = true
            }
        }
    }
    
    // 有没有一个可以下的点
    func hasAnyValidMove(for player: Piece) -> Bool {
        for i in 0..<8 {
            for j in 0..<8 {
                if isValidDrop(row: i, col: j, player: player) {
                    return true
                }
            }
        }
        return false
    }
    
    // 重新开始一局
    func reset() {
        board = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        board[3][3] = .white
        board[3][4] = .black
        board[4][3] = .black
        board[4][4] = .white
        currentPlayer = .black
        gameOver = false
        updateScores()
    }
}

// MARK: - View
struct CellView: View {
    @ObservedObject var game: ReversiGame
    let row: Int
    let col: Int
    
    @State private var flip = false

    var body: some View {
        Group {
            ZStack {
                Rectangle()
                    .fill(Color.green)
                if game.board[row][col] != .empty {
                    Circle()
                        .fill(game.board[row][col] == .black ? Color.black : Color.white)
                        .padding(4)
                        .rotation3DEffect(
                            flip ? .degrees(180) : .zero,
                            axis: (x: 0.0, y: 1.0, z: 0.0)
                        )
                        .onChange(of: game.board[row][col]) { oldValue, newValue in
                            withAnimation(.easeInOut(duration: 0.5)) {
                                flip.toggle()
                            }
                        }
                }
                if game.isValidDrop(row: row, col: col, player: game.currentPlayer) {
                    Circle()
                        .fill((game.currentPlayer == .black ? Color.black : Color.white).opacity(0.6))
                        .padding(18)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .contentShape(Rectangle()) // 保证点击区域全覆盖
    }
}

// 计分板 竖屏版
struct ScoreView: View {
    @ObservedObject var game: ReversiGame
    
    var body: some View {
        HStack {
            Spacer()
            PlayerScoreView(player: .black, count: game.blackScore, isCurrentPlayer: game.currentPlayer == .black ? true : false)
            Spacer()
            PlayerScoreView(player: .empty, count: game.emptyCells, isCurrentPlayer: false)
            Spacer()
            PlayerScoreView(player: .white, count: game.whiteScore, isCurrentPlayer: game.currentPlayer == .white ? true : false)
            Spacer()
        }
        .padding()
    }
}
// 计分板 横屏版
struct LandscapeScoreView: View {
    @ObservedObject var game: ReversiGame
    
    var body: some View {
        VStack {
            Spacer()
            PlayerScoreView(player: .black, count: game.blackScore, isCurrentPlayer: game.currentPlayer == .black ? true : false)
            Spacer()
            PlayerScoreView(player: .empty, count: game.emptyCells, isCurrentPlayer: false)
            Spacer()
            PlayerScoreView(player: .white, count: game.whiteScore, isCurrentPlayer: game.currentPlayer == .white ? true : false)
            Spacer()
        }
        .padding()
    }
}

// 单个玩家分数视图
struct PlayerScoreView: View {
    let player: Piece
    let count: Int
    let isCurrentPlayer: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(player == .black ? Color.black : player == .white ? Color.white : Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .padding(4)
            Text("\(count)")
                .font(.title.bold())
                .foregroundColor(player == .black ? Color.white : Color.black)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill((isCurrentPlayer ? Color.green : Color.gray).opacity(0.75)))
    }
}

// 控制面板
struct ControlView: View {
    @ObservedObject var game: ReversiGame
    @State private var showResetConfirmation = false

    var body: some View {
        VStack {
            Button("重新开始") {
                if game.gameOver {
                    game.reset()
                } else {
                    showResetConfirmation = true
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .alert("确认重新开始", isPresented: $showResetConfirmation) {
                Button("取消", role: .cancel) {}
                Button("确定", role: .destructive) {
                    game.reset()
                }
            } message: {
                Text("确定要重新开始游戏吗？当前进度将会丢失。")
            }

            if game.gameOver {
                Text("游戏结束")
                    .font(.title)
                    .foregroundColor(.blue)
                Text(game.blackScore > game.whiteScore ? "黑方胜" :
                     game.whiteScore > game.blackScore ? "白方胜" : "平局")
                    .font(.title)
                    .foregroundColor(.red)
            }
        }
    }
}

// 棋盘视图
struct BoardView: View {
    @ObservedObject var game: ReversiGame
    
    var body: some View {
        Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            ForEach(0..<8, id: \.self) { row in
                GridRow {
                    ForEach(0..<8, id: \.self) { col in
                        CellView(game: game, row: row, col: col)
                        .border(Color.black, width: 0.5)
                        .onTapGesture {
                            if !game.gameOver {
                                game.dropOnePiece(row: row, col: col)
                            }
                        }
                    }
                }
            }
        }
        .border(Color.black, width: 1)
        .background(Color.black)
    }
}

// 版本信息
struct copyrightView: View {
    // 计算属性获取版本信息
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "Version \(version) (Build \(build))"
    }
    var body: some View {
        Text("设计者：Tim@博学堂\n版本号：\(appVersion)")
            .font(.footnote)
        .padding()
    }
}

// MARK: - ViewModel
struct ContentView: View {
    @StateObject var game = ReversiGame()

    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            ZStack {
                HStack {
                    Spacer()
                    VStack {
                        Spacer()
                        copyrightView()
                    }
                }
                if isPortrait {
                    // 竖屏版
                    VStack {
                        ControlView(game: game)
                        ScoreView(game: game)
                        BoardView(game: game)
                            .frame(width: min(geometry.size.width, geometry.size.height) * 0.95,
                                   height: min(geometry.size.width, geometry.size.height) * 0.95)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.green.opacity(0.3))
                } else {
                    // 横屏版
                    HStack {
                        VStack {
                            Spacer()
                            LandscapeScoreView(game: game)
                        }
                        BoardView(game: game)
                            .frame(width: min(geometry.size.width, geometry.size.height) * 0.95,
                                   height: min(geometry.size.width, geometry.size.height) * 0.95)
                        VStack {
                            ControlView(game: game)
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.green.opacity(0.3))
                }
            }
        }
    }
}
