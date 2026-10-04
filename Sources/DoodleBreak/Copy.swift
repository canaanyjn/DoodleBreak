import Foundation

struct Stretch: Hashable {
    let text: String
}

/// 所有文案都集中在这里，方便改口味
enum Copy {
    static var stretches: [Stretch] { [
        L10n.text("双手举过头顶，伸个大懒腰，保持 10 秒", "Reach both arms overhead and stretch for 10 seconds"),
        L10n.text("走到窗边，看看 6 米外的东西 20 秒", "Look out a window at something far away for 20 seconds"),
        L10n.text("去接一杯水，顺便活动活动", "Get a glass of water and move around a little"),
        L10n.text("踮脚尖 15 次，唤醒小腿", "Rise onto your toes 15 times"),
        L10n.text("慢慢转动脖子，左三圈、右三圈", "Gently turn your head from side to side"),
        L10n.text("双手背后交叉，挺胸打开肩膀 15 秒", "Clasp your hands behind you and open your shoulders for 15 seconds"),
        L10n.text("扶着桌子做 10 个深蹲", "Hold a sturdy desk and try 10 gentle squats"),
        L10n.text("闭眼深呼吸 5 次：吸 4 秒，呼 6 秒", "Close your eyes for 5 slow breaths: in for 4, out for 6"),
        L10n.text("在房间里慢慢走两圈", "Take a couple of slow laps around the room"),
        L10n.text("手臂向前、向后各绕 10 圈", "Circle your arms forward and backward 10 times"),
        L10n.text("靠墙站直 30 秒：后脑、肩、臀贴墙", "Stand tall against a wall for 30 seconds"),
        L10n.text("学猫咪弓背再塌腰，各做 5 次", "Try 5 gentle cat-cow stretches"),
        L10n.text("原地高抬腿踏步 30 下", "March in place for 30 steps"),
        L10n.text("十指交叉翻掌向前推，拉伸手腕 10 秒", "Interlace your fingers, palms out, and stretch for 10 seconds"),
    ].map(Stretch.init(text:)) }

    static var breakTitles: [String] { [
        L10n.text("该起来动一动啦", "Time to get moving"),
        L10n.text("屁股解放时间到", "Give your chair a break"),
        L10n.text("腰椎在向你求救", "Your back needs a break"),
        L10n.text("起立！向椅子说再见", "Stand up and stretch"),
        L10n.text("身体：能放我出去转转吗", "How about a little walk?"),
        L10n.text("久坐警报，请离开座位", "Time away from your seat"),
    ] }

    static func quips(for mood: Mood, snoozeCount: Int) -> [String] {
        if snoozeCount >= 2 && (mood == .tired || mood == .urgent) {
            return [
                L10n.text("已延后 \(snoozeCount) 次，忙完记得活动一下", "Postponed \(snoozeCount) times. Stretch when you have a moment."),
                L10n.text("椅子：它今天是不是不打算走了？", "Your chair will still be here when you return."),
                L10n.text("有空时，站起来走两步吧", "When you have a moment, take a few steps."),
            ]
        }
        switch mood {
        case .fresh:
            return [L10n.text("刚坐下，元气满满！", "A fresh start!"), L10n.text("今天也要好好工作呀", "Have a good day at work."), L10n.text("咖啡准备好了吗？", "Coffee ready?"),
                    L10n.text("坐姿端正一点，腰会感谢你的", "Sit comfortably. Your back will thank you."), L10n.text("新的一轮开始，冲鸭", "A new round begins!")]
        case .okay:
            return [L10n.text("坐了一会儿了，腰还好吗？", "How is your back feeling?"), L10n.text("记得多眨眨眼", "Remember to blink."), L10n.text("喝口水吧", "Have a sip of water."),
                    L10n.text("肩膀是不是又耸起来了？放松放松", "Let those shoulders relax."), L10n.text("过半了，继续保持～", "Over halfway there.")]
        case .tired:
            return [L10n.text("屁股是不是有点麻了…", "Ready for a change of position?"), L10n.text("快了快了，马上就能起来", "Nearly time for a stretch."), L10n.text("我替你的腰椎捏把汗", "Your back could use a little movement."),
                    L10n.text("再坚持一下，然后去溜达溜达", "A little walk is coming up."), L10n.text("眼睛酸了吧，看看远处", "Rest your eyes by looking into the distance.")]
        case .urgent:
            return [L10n.text("就要到点了！准备起身", "Almost time to stand up!"), L10n.text("腿还在吗？动动脚趾确认一下", "Give your toes a little wiggle."),
                    L10n.text("倒计时中…准备好起身的仪式感", "Get ready for your break."), L10n.text("椅子快被你坐出人形了", "Your chair could use some time off.")]
        case .stretching:
            return [L10n.text("起来啦起来啦！", "Up we go!"), L10n.text("伸个懒腰吧～", "Enjoy a good stretch."), L10n.text("走两步，看看窗外", "Walk a little and look outside."),
                    L10n.text("身体：终于！", "A welcome change of pace!"), L10n.text("这几分钟属于你的腰和腿", "These minutes are for you.")]
        case .sleeping:
            return [L10n.text("zZZ… 暂停中", "zZZ… Paused"), L10n.text("开完会记得叫醒我", "Wake me after the meeting."), L10n.text("我先眯一会儿，你忙", "I'll rest while you're busy."), L10n.text("忙完后，记得回来继续计时", "Resume the timer when you're ready.")]
        }
    }

    static func snoozeLabel(count: Int, minutes: Int) -> String {
        L10n.text("稍后提醒（\(minutes) 分钟）", "Later (\(minutes) min)")
    }

    static func snoozeQuip(count: Int, minutes: Int) -> String {
        L10n.text("好的，\(minutes) 分钟后再提醒你", "Okay, I will remind you in \(minutes) min.")
    }
}
