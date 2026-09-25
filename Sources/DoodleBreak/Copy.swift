import Foundation

struct Stretch: Hashable {
    let text: String
}

/// 所有文案都集中在这里，方便改口味
enum Copy {
    static let stretches: [Stretch] = [
        "双手举过头顶，伸个大懒腰，保持 10 秒",
        "走到窗边，看看 6 米外的东西 20 秒",
        "去接一杯水，顺便活动活动",
        "踮脚尖 15 次，唤醒小腿",
        "慢慢转动脖子，左三圈、右三圈",
        "双手背后交叉，挺胸打开肩膀 15 秒",
        "扶着桌子做 10 个深蹲",
        "闭眼深呼吸 5 次：吸 4 秒，呼 6 秒",
        "在房间里慢慢走两圈",
        "手臂向前、向后各绕 10 圈",
        "靠墙站直 30 秒：后脑、肩、臀贴墙",
        "学猫咪弓背再塌腰，各做 5 次",
        "原地高抬腿踏步 30 下",
        "十指交叉翻掌向前推，拉伸手腕 10 秒",
    ].map(Stretch.init(text:))

    static let breakTitles = [
        "该起来动一动啦",
        "屁股解放时间到",
        "腰椎在向你求救",
        "起立！向椅子说再见",
        "身体：能放我出去转转吗",
        "久坐警报，请离开座位",
    ]

    static func quips(for mood: Mood, snoozeCount: Int) -> [String] {
        if snoozeCount >= 2 && (mood == .tired || mood == .urgent) {
            return [
                "已经赖了 \(snoozeCount) 次了，我都替你脸红",
                "椅子：它今天是不是不打算走了？",
                "这一轮赖了 \(snoozeCount) 次，腰椎已提交投诉",
            ]
        }
        switch mood {
        case .fresh:
            return ["刚坐下，元气满满！", "今天也要好好工作呀", "咖啡准备好了吗？",
                    "坐姿端正一点，腰会感谢你的", "新的一轮开始，冲鸭"]
        case .okay:
            return ["坐了一会儿了，腰还好吗？", "记得多眨眨眼", "喝口水吧",
                    "肩膀是不是又耸起来了？放松放松", "过半了，继续保持～"]
        case .tired:
            return ["屁股是不是有点麻了…", "快了快了，马上就能起来", "我替你的腰椎捏把汗",
                    "再坚持一下，然后去溜达溜达", "眼睛酸了吧，看看远处"]
        case .urgent:
            return ["就要到点了！准备起身", "腿还在吗？动动脚趾确认一下",
                    "倒计时中…准备好起身的仪式感", "椅子快被你坐出人形了"]
        case .stretching:
            return ["起来啦起来啦！", "伸个懒腰吧～", "走两步，看看窗外",
                    "身体：终于！", "这几分钟属于你的腰和腿"]
        case .sleeping:
            return ["zZZ… 暂停中", "开完会记得叫醒我", "我先眯一会儿，你忙", "暂停不是赖床的借口哦"]
        }
    }

    static func snoozeLabel(count: Int, minutes: Int) -> String {
        switch count {
        case 0: return "再赖 \(minutes) 分钟"
        case 1: return "还要赖？再 \(minutes) 分钟"
        default: return "屁股要长椅子上了…再 \(minutes) 分钟"
        }
    }

    static func snoozeQuip(count: Int, minutes: Int) -> String {
        switch count {
        case 1: return "好吧，就 \(minutes) 分钟哦，我盯着呢"
        case 2: return "第二次了…腰椎已经开始写投诉信"
        default: return "赖了 \(count) 次，我决定叫你椅子精"
        }
    }
}
