do
    ----SomeToolKits
    do

        function CheckIfVisible(originVec3, targetVec3) --返回originVec3头顶上2m到targetVec3头顶上2m的射线段上是否无地形遮挡，无地形遮挡返回true
            if originVec3 ~= nil and targetVec3 ~= nil then
                local movedOriginVec3 = {
                    x = originVec3.x,
                    y = originVec3.y + 2,
                    z = originVec3.z
                }
                local movedTargetVec3 = {
                    x = targetVec3.x,
                    y = targetVec3.y + 2,
                    z = targetVec3.z
                }
                return land.isVisible(movedOriginVec3, movedTargetVec3)
            end
            return false
        end

        function FunctionPackerAndCaller(functionPack) --如果某个沙雕传函数的方法只允许你传一个参数进去,就使用这个蛇东西包起来传你需要传的方法,functionPack原型参看定义
            --[[functionPack={
                calledFunction,
                argsPack
            }--]]
            if functionPack.argsPack == nil then
                return functionPack.calledFunction()
            end

            return functionPack.calledFunction(functionPack.argsPack.theCallerSelf, functionPack.argsPack)
        end

        function SendMessageForRangeReference(text, displayTime, rangeReference, clearView) --rangeReference不填默认为全体广播
            local range = 0
            local reference = nil

            if rangeReference ~= nil then
                range = rangeReference.range
                reference = rangeReference.reference
            end

            if range == 0 then
                trigger.action.outText(text, displayTime, clearView)
            elseif range == 1 then
                trigger.action.outTextForCoalition(reference, text, displayTime,
                    clearView)
            elseif range == 2 then
                trigger.action.outTextForGroup(reference:getID(), text, displayTime, clearView)
            end
        end

        function DebugMessage(numOrString)
            local msg = "helloWorld"
            if numOrString ~= nil then
                msg = msg .. numOrString
            end
            SendMessageForRangeReference(msg, 5)
        end

        --管理全阵营共享的用户标记
        do
            UserMarkHandler = {}

            UserMarkHandler.Ignore = {
                Text = "*ERD*",
                Check = function(markText)
                    if string.find(markText, UserMarkHandler.Ignore.Text) ~= nil then
                        return true
                    end
                    return false
                end
            }

            UserMarkHandler.redMarkVec3 = nil
            UserMarkHandler.blueMarkVec3 = nil
            UserMarkHandler.RecallLinkList = {
                head = {
                    ahead = nil,
                    functionPack = nil,
                    next = {
                        ahead = nil,
                        functionPack = nil,
                        next = nil
                    }
                },

                Insert = function(functionPack) --返回的是recallNode的索引，保存以用于delete节点
                    local recallNode = {
                        ahead = UserMarkHandler.RecallLinkList.head,
                        functionPack = functionPack,
                        next = UserMarkHandler.RecallLinkList.head.next
                    }

                    UserMarkHandler.RecallLinkList.head.next = recallNode
                    recallNode.next.ahead = recallNode
                    return recallNode
                end,

                Delete = function(recallNode)
                    if recallNode.functionPack ~= nil then
                        recallNode.ahead.next = recallNode.next
                        recallNode.next.ahead = recallNode.ahead

                        recallNode.ahead = nil
                        recallNode.functionPack = nil
                        recallNode.next = nil
                    end
                end
            } --回调函数链表{ahead,functionPack,next}，会在下事件handler执行的时候用FunctionPackerAndCaller把functionPack挨个执行过去
            UserMarkHandler.RecallLinkList.head.next.ahead = UserMarkHandler.RecallLinkList.head

            function UserMarkHandler.AddUserMark(event)
                if event.id == 25 then
                    --DXbugMessage(event.text)
                    if not UserMarkHandler.Ignore.Check(event.text) then
                        --DXbugMessage(73)
                        if event.coalition == coalition.side["RED"] then
                            UserMarkHandler.redMarkVec3 = event.pos
                            SendMessageForRangeReference("增加了新的地图标记", 5,
                                { range = 1, reference = coalition.side["RED"] })
                        elseif event.coalition == coalition.side["BLUE"] then
                            UserMarkHandler.blueMarkVec3 = event.pos
                            SendMessageForRangeReference("增加了新的地图标记", 5,
                                { range = 1, reference = coalition.side["BLUE"] })
                        end

                        do
                            local currentRecallNode = UserMarkHandler.RecallLinkList.head.next
                            while currentRecallNode.functionPack ~= nil do
                                FunctionPackerAndCaller(currentRecallNode.functionPack)
                                currentRecallNode = currentRecallNode.next
                            end
                        end
                    end
                end
            end

            function UserMarkHandler.GetMyMark(rangeReference)
                if WhichIsMyCoalition(rangeReference) == coalition.side["RED"] then
                    return UserMarkHandler.redMarkVec3
                elseif WhichIsMyCoalition(rangeReference) == coalition.side["BLUE"] then
                    return UserMarkHandler.blueMarkVec3
                end
            end

            mist.addEventHandler(UserMarkHandler.AddUserMark)
        end

        function WhichIsMyCoalition(rangeReference) --返回enum coalition.side
            if rangeReference.range == 1 then
                return rangeReference.reference
            elseif rangeReference.range == 2 then
                return rangeReference.reference:getCoalition()
            end
            return nil
        end

        --包好的TryWithoutObjectNilException工具包，它们可以避免因空值输入和输入阵亡对象、未激活对象等原因造成的Exception
        do
            TryWithoutObjectNilException = {}

            function TryWithoutObjectNilException.UnitGetPoint(unit) --替换原版的Unit:getPoint
                if unit == nil then
                    return nil
                end

                if unit:isExist() then
                    if unit:isActive() then
                        return unit:getPoint()
                    end
                end
                return nil
            end

            function TryWithoutObjectNilException.IsTargetDetectedAndVisible(selfUnit, targetUnit) --替换原版的Controller.isTargetDetected
                if selfUnit == nil or targetUnit == nil then
                    return false
                end

                if selfUnit:isExist() and targetUnit:isExist() then
                    if selfUnit:isActive() and targetUnit:isActive() then
                        local detected, visible = selfUnit:getController():
                            isTargetDetected(targetUnit)
                        return visible and detected
                    end
                end
                return false
            end
        end
    end


    ----EnhancedCommandManagement
    do
        --与游戏内的无线电同步在CommandTree一层维护，当且仅当CommandTree实例有变化的时候要反映到游戏内

        do
            CommandNode = {}

            function CommandNode.New(text, isCommand, commandFunction, ...) --text:节点文本;isCommand:是指令吗？;commandFunction:指令所要执行的函数，当且仅当是指令的时候要填写，后面可以跟上该函数的参数，注意：并非argsPack传递法
                local node = {}
                node.tree = nil --快速找树
                node.lastTree = nil --记录最后一个从属树
                node.parent = nil --父节点
                node.text = text --显示在无线电菜单中的文本
                node.isCommand = isCommand --是指令吗？
                node.commandFunction = commandFunction --指令所要执行的函数
                node.xArg = { ... }
                node.childrenLinkList = { --孩子链表，表头的data是表长，后续节点的data是孩子节点
                    data = 0,
                    next = nil
                }

                function node:setTree(tree)
                    if tree == nil then
                        node.tree = nil
                    else
                        node.tree = tree
                        node.lastTree = node.tree
                    end
                end

                function node:safeCommandFunction()

                    --DXbugMessage(1919810)

                    if node.tree ~= node.lastTree then
                        SendMessageForRangeReference("指令已过期，请刷新一下无线电菜单", 5,
                            node.lastTree.rangeReference)
                    else
                        commandFunction(unpack(node.xArg))
                    end
                end

                function node:getDepth()
                    local depth = 0
                    do
                        local i = 0
                        local currentNode = node
                        while currentNode.parent ~= nil do
                            i = i + 1
                            currentNode = currentNode.parent
                        end
                        depth = i
                    end

                    return depth
                end

                function node:showPath() --给出含本节点的菜单路径字符串数组
                    local path = {}
                    local currentNode = node
                    local depth = node:getDepth()

                    local displayLockerDepth = -1
                    if node.tree ~= nil then
                        displayLockerDepth = node.tree:getDisplayLockerDepth()
                    end

                    do
                        local i = depth - displayLockerDepth
                        while i > 0 do
                            path[i] = currentNode.text
                            currentNode = currentNode.parent
                            i = i - 1
                        end
                    end

                    return path
                end

                function node:dfsImplement() --从本节点起把整个子树刷进无线电菜单里
                    local path = node:showPath()
                    table.remove(path)

                    if node.isCommand then
                        if node.tree.rangeReference.range == 0 then
                            missionCommands.addCommand(node.text, path, node.safeCommandFunction, node)
                        elseif node.tree.rangeReference.range == 1 then
                            missionCommands.addCommandForCoalition(node.tree.rangeReference.reference, node.text, path,
                                node.safeCommandFunction, node)
                        elseif node.tree.rangeReference.range == 2 then
                            missionCommands.addCommandForGroup(node.tree.rangeReference.reference:getID(), node.text,
                                path,
                                node.safeCommandFunction, node)
                        end
                    else
                        if node.tree.rangeReference.range == 0 then
                            missionCommands.addSubMenu(node.text, path)
                        elseif node.tree.rangeReference.range == 1 then
                            missionCommands.addSubMenuForCoalition(node.tree.rangeReference.reference, node.text, path)
                        elseif node.tree.rangeReference.range == 2 then
                            missionCommands.addSubMenuForGroup(node.tree.rangeReference.reference:getID(), node.text,
                                path)
                        end
                    end

                    do
                        local i = node.childrenLinkList.next
                        while i ~= nil do
                            i.data:dfsImplement()
                            i = i.next
                        end
                    end
                end

                function node:implementMyChildren() --按顺序把孩子子树刷进来
                    do
                        local i = node.childrenLinkList.next
                        while i ~= nil do
                            i.data:dfsImplement()
                            i = i.next
                        end
                    end
                end

                function node:deImplement() --deImplement操作不会因为匹配不到对象而exception
                    local path = node:showPath()

                    if node.tree.rangeReference.range == 0 then
                        missionCommands.removeItem(path)
                    elseif node.tree.rangeReference.range == 1 then
                        missionCommands.removeItemForCoalition(node.tree.rangeReference.reference, path)
                    elseif node.tree.rangeReference.range == 2 then
                        missionCommands.removeItemForGroup(node.tree.rangeReference.reference:getID(), path)
                    end
                end

                function node:deImplementMyChildren() --把孩子全deImplement掉
                    do
                        local i = node.childrenLinkList.next
                        while i ~= nil do
                            i.data:deImplement()
                            i = i.next
                        end
                    end
                end

                function node:reImplementMyChildren() --很明显，先把孩子deImplement掉再implement进来
                    node:deImplementMyChildren()
                    node:implementMyChildren()
                end

                function node:reImplement() --把本节点兄弟节点全部deImplement掉再重新刷进来
                    node.parent:reImplementMyChildren()
                end

                function node:dirAddNode(childNode) --直球尾插
                    node.childrenLinkList.data = node.childrenLinkList.data + 1

                    do
                        local i = node.childrenLinkList
                        while i.next ~= nil do
                            i = i.next
                        end
                        i.next = {
                            data = childNode,
                            next = nil
                        }
                    end

                    childNode.parent = node
                end

                function node:dirDisconnectNode(childNode) --直球断开，将以本节点的某个孩子节点为根节点的子树从切下来
                    do
                        local i = node.childrenLinkList
                        local cutbed = nil
                        while i.next ~= nil do
                            if i.next.data == childNode then
                                cutbed = i
                            end
                            i = i.next
                        end
                        if cutbed ~= nil then
                            cutbed.next = cutbed.next.next
                            node.childrenLinkList.data = node.childrenLinkList.data - 1
                            childNode:setTree(nil)
                            childNode.parent = nil
                        end
                    end
                end

                function node:dirDisconnect() --直球断开，把以自己为根的子树从父节点上切下去
                    if node.parent ~= nil then
                        node.parent:dirDisconnectNode(node)
                    end
                end

                function node:dfsSetTree() --将本节点为根节点的子树下所有节点的tree设置为和本节点相同
                    do
                        local i = node.childrenLinkList.next
                        while i ~= nil do
                            i.data:setTree(node.tree)
                            i.data:dfsSetTree()

                            i = i.next
                        end
                    end
                end

                function node:dfsFree() --用法：nodeInstance=nodeInstance:dfsFree()
                    do
                        local i = node.childrenLinkList.next
                        while i ~= nil do
                            i.data:dfsFree()
                            i.data.parent = nil
                            i.data.childrenLinkList = nil
                            i.data = nil
                            i = i.next
                        end
                    end
                    return nil
                end

                return node
            end

            function CommandNode.NewByArgsPack(text, isCommand, commandFunction, argsPack)
                return CommandNode.New(text, isCommand, commandFunction, argsPack.theCallerSelf, argsPack)
            end
        end

        do
            CommandTree = {}

            function CommandTree.New(rangeReference)
                local tree = {}
                tree.displayLockerCommandNode = nil --这个量用于进行局部显示
                tree.rangeReference = {
                    range = rangeReference.range,
                    reference = rangeReference.reference
                }

                local rootNodeText = ""
                if tree.rangeReference.range == 0 then
                    rootNodeText = "全局无线电"
                elseif tree.rangeReference.range == 1 then
                    rootNodeText = "阵营无线电"
                elseif tree.rangeReference.range == 2 then
                    rootNodeText = "群组无线电"
                end

                function tree:setDisplayLockerCommandNode(displayLockerCommandNode) --调用这个函数将使整个无线电树从传入参数的孩子节点开始显示，传入nil则恢复原状
                    tree.rootNode:deImplement()

                    tree.displayLockerCommandNode = displayLockerCommandNode

                    if displayLockerCommandNode == nil then
                        tree.rootNode:dfsImplement()
                    else
                        tree.displayLockerCommandNode:implementMyChildren()
                    end
                end

                function tree:getDisplayLockerDepth()
                    if tree.displayLockerCommandNode == nil then
                        return -1
                    end
                    return tree.displayLockerCommandNode:getDepth()
                end

                function tree:addNode(parentNode, childNode) --parentNode:当前树下欲插入子树的节点，本参数必须是一个非指令节点；
                    if (not parentNode.isCommand) and parentNode.tree == tree then
                        parentNode:dirAddNode(childNode)

                        childNode:setTree(tree)
                        childNode:dfsSetTree()

                        childNode:dfsImplement()
                    end
                end

                function tree:addNodes(parentNode, childNodes) --群体尾插
                    if (not parentNode.isCommand) and parentNode.tree == tree then
                        do
                            local i = 1
                            while childNodes[i] ~= nil do
                                parentNode:dirAddNode(childNodes[i])

                                i = i + 1
                            end
                            parentNode:dfsSetTree()
                            parentNode:reImplementMyChildren()
                        end
                    end
                end

                function tree:deleteChildren(parentNode) --清掉parentNode下所有孩子节点，从内存空间中释放
                    parentNode:deImplementMyChildren()
                    do
                        local currentChildListNode = parentNode.childrenLinkList.next
                        while parentNode.childrenLinkList.data > 0 do
                            --SendMessageForRangeReference("clearing:" .. parentNode.childrenLinkList.data, 5)
                            parentNode:dirDisconnectNode(currentChildListNode.data)
                            currentChildListNode.data = currentChildListNode.data:dfsFree()
                            currentChildListNode.next = nil
                            currentChildListNode = parentNode.childrenLinkList.next
                        end
                    end
                end

                function tree:disconnectNode(childNode) --你不能disconnect根节点
                    if childNode.tree == tree and childNode ~= tree.rootNode then
                        local currentNode = childNode.parent
                        currentNode:deImplementMyChildren()
                        currentNode:dirDisconnectNode(childNode)
                        currentNode:implementMyChildren()
                    end
                end

                function tree:deleteSubTree(childNode) --删除以childNode为根的子树，从内存空间中释放
                    tree:disconnectNode(childNode)
                    childNode:dfsFree()
                end

                function tree:replaceNode(targetNode, newNode) --你不能replace根节点；targetNode会被disconnect掉并改接上以newNode为根节点的子树
                    if targetNode.tree == tree and targetNode ~= tree.rootNode then
                        local currentNode = targetNode.parent
                        currentNode:deImplementMyChildren()
                        currentNode:dirDisconnectNode(targetNode)

                        currentNode:dirAddNode(newNode)
                        newNode:setTree(tree)
                        newNode:dfsSetTree()

                        currentNode:implementMyChildren()
                    end
                end

                function tree:replaceCommand(targetNode, newNode) --targetNode和coverNode必须均为command
                    if targetNode.isCommand and newNode.isCommand then
                        tree:replaceNode(targetNode, newNode)
                    end
                end

                tree.rootNode = CommandNode.New(rootNodeText, false)
                tree.rootNode:setTree(tree)
                tree.rootNode:dfsImplement()

                return tree
            end
        end
    end

    --EnhancedDataLinkManagement
    do
        --[[
            本类用于产生和管理以自定义无线电形式存在的数据链目标
            一个Pad就是一个具体的数据链终端
        --]]

        --目标管理器类
        do
            TargetsManagement = {}

            function TargetsManagement.New(linkPad)
                local targetsManagement = {}
                targetsManagement.linkPad = linkPad
                targetsManagement.spiVec3 = nil --当且仅当是nil的时候代表不存在SPI
                targetsManagement.spiMistMark = nil

                targetsManagement.trackingFunction = nil --用本类里的方法来刷入这个函数型成员，这个成员将以4HZ的频率执行，直到它返回nil或trackingCanceler被拉起为止
                targetsManagement.trackingFunctionArgsPack = nil
                targetsManagement.trackingStoper = true --为true时，trackingFunction的执行将在下一次后停止
                targetsManagement.autoSetSPIByUserMarkRecallNode = nil

                function targetsManagement:getRangeReference()
                    return targetsManagement.linkPad.rangeReference
                end

                function targetsManagement:stopTracking()
                    if targetsManagement.trackingFunction ~= nil then
                        SendMessageForRangeReference("对侦查目标的跟踪已停止", 5,
                            targetsManagement:getRangeReference())
                    end
                    targetsManagement.trackingStoper = true
                    --DXbugMessage(11)
                end

                function targetsManagement:trackingHandler()
                    if targetsManagement.trackingStoper then
                        targetsManagement.trackingFunction = nil
                        targetsManagement.trackingFunctionArgsPack = nil
                        --DXbugMessage(12)
                        return nil
                    end

                    if targetsManagement.trackingFunction ~= nil then
                        if targetsManagement.trackingFunctionArgsPack == nil then

                            --DXbugMessage(13)
                            targetsManagement.trackingFunction()
                        else

                            --DXbugMessage(14)
                            targetsManagement.trackingFunction(targetsManagement.trackingFunctionArgsPack.theCallerSelf
                                ,
                                targetsManagement.trackingFunctionArgsPack)
                        end

                        return timer.getTime() + 0.241
                    end
                    return nil
                end

                function targetsManagement:setTrackingFunction(trackingFunction, argsPack) --若argsPack不为nil则trackingFunction被call的时候将这样装填：trackingFunction(argsPack.theCallerSelf,argsPack)

                    if targetsManagement.trackingStoper then
                        targetsManagement.trackingFunction = trackingFunction
                        targetsManagement.trackingFunctionArgsPack = argsPack
                        targetsManagement.trackingStoper = false
                        timer.scheduleFunction(targetsManagement.trackingHandler, { targetsManagement },
                            timer.getTime() + 0.232)

                        targetsManagement:switchOffAutoSetSPIByUserMark()
                    else
                        targetsManagement.trackingFunction = trackingFunction
                        targetsManagement.trackingFunctionArgsPack = argsPack
                    end

                end

                function targetsManagement:clearTrackingFunction()
                    targetsManagement.trackingFunctionArgsPack = nil
                    targetsManagement.trackingFunction = nil
                end

                function targetsManagement:getSPIVec3()
                    return targetsManagement.spiVec3
                end

                function targetsManagement:setSPIByVec3(pointVec3)
                    targetsManagement.spiVec3 = pointVec3
                end

                function targetsManagement:setGourndSPI(pointVec2orVec3) --传Vec3或Vec2进来都可以
                    targetsManagement:setSPIByVec3(mist.utils.makeVec3GL(pointVec2orVec3))
                end

                function targetsManagement:clearSPI()
                    targetsManagement:setSPIByVec3(nil)
                end

                function targetsManagement:dirSetSPIByUserMark()
                    local markVec3 = UserMarkHandler.GetMyMark(targetsManagement:getRangeReference())

                    if markVec3 == nil then
                        SendMessageForRangeReference("尚未设定地图标记，请用f10地图标记进行设置",
                            5, targetsManagement:getRangeReference())
                        return nil
                    end

                    SendMessageForRangeReference("已设定SPI为地图标记", 5, targetsManagement:getRangeReference())
                    targetsManagement:setGourndSPI(markVec3)
                end

                function targetsManagement:setSPIByUserMark()
                    targetsManagement:dirSetSPIByUserMark()

                    targetsManagement:switchOffAutoSetSPIByUserMark()
                    targetsManagement:stopTracking()
                end

                function targetsManagement:switchOffAutoSetSPIByUserMark()
                    if targetsManagement.autoSetSPIByUserMarkRecallNode ~= nil then
                        SendMessageForRangeReference("已停止自动接收用户标记", 5,
                            targetsManagement:getRangeReference())
                        UserMarkHandler.RecallLinkList.Delete(targetsManagement.autoSetSPIByUserMarkRecallNode)
                        targetsManagement.autoSetSPIByUserMarkRecallNode = nil
                    end
                end

                function targetsManagement:switchAutoSetSPIByUserMark()
                    --DXbugMessage(1)
                    if targetsManagement.autoSetSPIByUserMarkRecallNode == nil then
                        local functionPack = {
                            calledFunction = targetsManagement.dirSetSPIByUserMark,
                            argsPack = {
                                theCallerSelf = targetsManagement
                            }
                        }
                        --DXbugMessage(2)

                        targetsManagement.autoSetSPIByUserMarkRecallNode = UserMarkHandler.RecallLinkList.Insert(functionPack)
                        --DXbugMessage(3)

                        targetsManagement:stopTracking()
                        --DXbugMessage(4)

                        SendMessageForRangeReference("已启用自动获取地图坐标为SPI", 5,
                            targetsManagement:getRangeReference())
                    else
                        targetsManagement:switchOffAutoSetSPIByUserMark()
                    end
                end

                function targetsManagement:spiDisplayHandler()
                    if targetsManagement.spiVec3 ~= nil then
                        if targetsManagement.spiMistMark ~= nil then
                            mist.marker.remove(targetsManagement.spiMistMark.markId)
                        end
                        local spiMarkIndex = {
                            pos = targetsManagement.spiVec3,
                            markType = 5,
                            text = "↙" .. UserMarkHandler.Ignore.Text .. " SPI",
                            markForCoa = WhichIsMyCoalition(targetsManagement.linkPad.rangeReference),
                            fontSize = 24,
                            fillColor = { 128, 0, 128, 96 },
                            color = { 0, 255, 0, 255 }
                        }
                        targetsManagement.spiMistMark = mist.marker.add(spiMarkIndex)
                    end

                    return timer.getTime() + 1
                end

                timer.scheduleFunction(targetsManagement.spiDisplayHandler, targetsManagement, 5)

                return targetsManagement
            end
        end

        --在链群组控制器类
        do
            OnlineGroupController = {}

            function OnlineGroupController.New(onlineGroup)
                local onlineGroupController = {}
                onlineGroupController.group = onlineGroup
                onlineGroupController.groupName = onlineGroup:getName()
                onlineGroupController.masterLinkPad = nil
                onlineGroupController.Public = {}

                --text(显示在无线电指令上的文字)不应被改动，commandFunction索引过去的东西可以改，enable决定了这个能力目前可用与否
                --头节点用来存激活开关指令，如果头结点的enable是true的话，后续所有capability的enable都会被当成是false
                --一个capability最多只能对应一个具体的commandNode；trashBin字段用来保存这个capability节点产生的commandNode用以便于实施清除
                onlineGroupController.missionCapability = {
                    head = nil,
                    data = {
                        text = "放飞" .. onlineGroupController.groupName,
                        commandFunction = onlineGroupController.activate,
                        argsPack = {
                            theCallerSelf = onlineGroupController
                        }
                    },
                    enable = not onlineGroupController.group:getUnits()[1]:isActive(),
                    trashBin = nil,
                    next = nil
                }
                onlineGroupController.missionCapability.head = onlineGroupController.missionCapability

                onlineGroupController.Recon = {}
                do
                    function onlineGroupController.Recon:search(unit, point)

                        --DXbugMessage(18)
                        local targetsBuffle = unit:getController():getDetectedTargets()
                        local targets = {}

                        do
                            local i = 1
                            while targetsBuffle[i] ~= nil do
                                local sourceUnitPoint = TryWithoutObjectNilException.UnitGetPoint(unit)
                                local targetUnitPoint = TryWithoutObjectNilException.UnitGetPoint(targetsBuffle[i].object)
                                if sourceUnitPoint ~= nil and targetUnitPoint ~= nil then
                                    if targetsBuffle[i].visible and targetsBuffle[i].type and targetsBuffle[i].distance then
                                        if mist.utils.get2DDist(targetUnitPoint, sourceUnitPoint) <
                                            onlineGroupController.reconCapability.distance and
                                            mist.utils.get2DDist(targetUnitPoint, point) <
                                            onlineGroupController.reconCapability.radius then

                                            table.insert(targets, targetsBuffle[i])
                                        end
                                    end
                                end
                                i = i + 1
                            end
                        end

                        local text = "检测到的目标有："

                        do
                            local i = 1
                            while targets[i] ~= nil do
                                text = text .. "\n" .. i .. ": " .. targets[i].object:getTypeName()
                                i = i + 1
                            end
                        end

                        SendMessageForRangeReference(text, 10, onlineGroupController:getRangeReference())

                        --DXbugMessage(20)
                        return targets
                    end
                end

                onlineGroupController.reconCapability = nil

                --工具函数包
                do
                    function onlineGroupController:getSPIVec3()
                        local point = onlineGroupController.masterLinkPad.targetsManagement:getSPIVec3()
                        if point == nil then
                            onlineGroupController.masterLinkPad:SPINotExistWarnMessage()
                        end
                        return point
                    end

                    function onlineGroupController:getRangeReference()
                        if onlineGroupController.masterLinkPad == nil then
                            return {
                                range = 1,
                                reference = onlineGroupController.group:getCoalition()
                            }
                        end
                        return onlineGroupController.masterLinkPad.rangeReference
                    end

                    function onlineGroupController:checkIfAble(unit) --检查unit机，失能返回false，否则返回true
                        if unit ~= nil then
                            if unit:isExist() then
                                if unit:isActive() then
                                    if (unit:getLife() / unit:getLife0() >= 0.9) and
                                        unit:getFuel() > 0.1 then
                                        return true
                                    end
                                end
                            end
                        end
                        return false
                    end

                    function onlineGroupController:getFirstAbleUnit() --返回组中第一个存活且未失能的机，若不存在这样的机则返回nil且返回前会把所有missionCapability的enable都置false，除非头结点的capability为true
                        if not onlineGroupController.group:isExist() then
                            return nil
                        end

                        local units = onlineGroupController.group:getUnits()
                        do
                            local i = 1
                            while units[i] ~= nil do
                                if onlineGroupController:checkIfAble(units[i]) then
                                    return (units[i])
                                end
                                i = i + 1
                            end
                        end

                        if not onlineGroupController.missionCapability.enable then
                            --DXbugMessage(25)
                            local i = onlineGroupController.missionCapability
                            while i ~= nil do
                                i.enable = false
                                i = i.next
                            end
                            onlineGroupController.masterLinkPad:implementOnlineGroupController(onlineGroupController)
                        end
                        return nil
                    end

                    function onlineGroupController:dirInsertCapabilityNode(data, enable) --enable不填默认是nil，相当于false，用尾插法
                        local missionCapabilityNode = {
                            head = onlineGroupController.missionCapability,
                            data = data,
                            enable = enable,
                            trashBin = nil,
                            next = nil
                        }

                        local currentNode = onlineGroupController.missionCapability
                        do
                            while currentNode.next ~= nil do
                                currentNode = currentNode.next
                            end
                        end

                        currentNode.next = missionCapabilityNode
                    end

                    function onlineGroupController:isMissionEnable() --判断性用法：if isMissionEnable~=nil then刷新群组是否可以响应指令，这个函数有无线电回复，返回getFirstAbleUnit的返回值
                        local unit = onlineGroupController:getFirstAbleUnit()
                        if unit == nil then
                            SendMessageForRangeReference("群组无响应", 5, onlineGroupController:getRangeReference())
                        end
                        return unit
                    end

                end

                --使能函数包
                do
                    function onlineGroupController:areaRecon() --实施区域侦查，显式地将侦查结果无线电回复，并将目标上行至数据链目标管理器
                        onlineGroupController.masterLinkPad.targetsManagement:stopTracking()

                        local point = onlineGroupController:getSPIVec3()
                        if point == nil then
                            return nil
                        end

                        local unit = onlineGroupController:isMissionEnable()
                        if unit == nil then
                            return nil
                        end

                        local targets = nil
                        if unit ~= nil then
                            --DXbugMessage(15)
                            targets = onlineGroupController.Recon:search(unit, point)
                            --DXbugMessage(16)
                            onlineGroupController.masterLinkPad:uploadTargets(targets, onlineGroupController, unit)
                            --DXbugMessage(17)
                        end
                    end

                    function onlineGroupController:activate()
                        SendMessageForRangeReference(onlineGroupController.groupName .. ":已出动", 5,
                            onlineGroupController:getRangeReference())
                        onlineGroupController.group:activate()
                        onlineGroupController.missionCapability.enable = false
                        onlineGroupController.masterLinkPad:implementOnlineGroupController(onlineGroupController)
                    end

                    function onlineGroupController:highAltitudeHorizontalBombing(argsPack) --实施高空水平定点轰炸
                        local point = onlineGroupController:getSPIVec3()
                        if point == nil then
                            return nil
                        end

                        local engage = {
                            id = "Bombing",
                            params = {
                                point = mist.utils.makeVec2(point),
                                attackQty = 1,
                                weaponType = argsPack.bombingParams.weaponType,
                                expend = argsPack.bombingParams.expend,
                                groupAttack = argsPack.bombingParams.groupAttack,
                                altitude = argsPack.bombingParams.altitude,
                                altitudeEnabled = argsPack.bombingParams.altitudeEnabled
                            }
                        }

                        if onlineGroupController:isMissionEnable() ~= nil then
                            SendMessageForRangeReference(onlineGroupController.groupName .. ":正在攻击", 5,
                                onlineGroupController:getRangeReference())
                            onlineGroupController.group:getController():pushTask(engage)
                        end
                    end

                    function onlineGroupController:searchAndHunting(argsPack) --搜索攻击SPI附近的地面目标
                        local point = onlineGroupController:getSPIVec3()
                        if point == nil then
                            return nil
                        end

                        local engage = {
                            id = "EngageTargetsInZone",
                            params = {
                                point = mist.utils.makeVec2(point),
                                zoneRadius = argsPack.zoneRadius,
                                targetTypes = { "All", }
                            }
                        }

                        if onlineGroupController:isMissionEnable() ~= nil then
                            SendMessageForRangeReference(onlineGroupController.groupName .. ":正在搜索和攻击"
                                , 5,
                                onlineGroupController:getRangeReference())
                            onlineGroupController.group:getController():pushTask(engage)
                        end
                    end

                    function onlineGroupController:refreshLaserSpot(argsPack) --刷新激光照射点
                        local point = onlineGroupController:getSPIVec3()
                        if point == nil then
                            return nil
                        end

                        local spot = argsPack.spot
                        local spotterUnit = argsPack.spotterUnit
                        local repeatedPeriod = 0.242
                        local reasonString = ":激光照射停止"

                        if onlineGroupController:checkIfAble(spotterUnit) then
                            if point ~= nil then
                                if argsPack.laserCapability.switch >= 0 then
                                    if argsPack.laserCapability.switch <= argsPack.laserCapability.overHeatedTime then
                                        if mist.utils.get3DDist(spotterUnit:getPoint(), point) <
                                            argsPack.laserCapability.distanceLimitation then
                                            if CheckIfVisible(spotterUnit:getPoint(), point) then
                                                spot:setPoint(point)
                                                argsPack.laserCapability.switch = argsPack.laserCapability.switch +
                                                    repeatedPeriod
                                                --DXbugMessage(" Switch=" .. argsPack.laserCapability.switch)
                                                return (timer.getTime() + repeatedPeriod)
                                            else
                                                reasonString = reasonString .. "-目标被遮挡"
                                            end
                                        else
                                            reasonString = reasonString .. "-超出距离限制"
                                        end
                                    else
                                        reasonString = reasonString .. "-激光器需要冷却"
                                    end
                                else

                                end
                            else
                                reasonString = reasonString .. "-没有可用的SPI"
                            end
                        else
                            reasonString = reasonString .. "-照射机已失去联系"
                        end

                        SendMessageForRangeReference(onlineGroupController.groupName .. reasonString,
                            5, onlineGroupController:getRangeReference())
                        argsPack.laserCapability.switch = -1
                        spot:destroy()
                        argsPack.spot = nil
                        return nil

                    end

                    function onlineGroupController:laserSpotting(argsPack) --开关激光照射
                        local point = onlineGroupController:getSPIVec3()
                        if point == nil then
                            return nil
                        end

                        local spotterUnit = onlineGroupController:isMissionEnable()
                        if spotterUnit ~= nil then


                            if argsPack.laserCapability.switch < 0 then
                                local spot = Spot.createLaser(spotterUnit, { x = 0, y = 0, z = 0 }, point,
                                    argsPack.laserCapability.laserCode)

                                argsPack.laserCapability.switch = 0.05
                                local functionPack = {
                                    calledFunction = onlineGroupController.refreshLaserSpot,
                                    argsPack = {
                                        theCallerSelf = onlineGroupController,
                                        spot = spot,
                                        spotterUnit = spotterUnit,
                                        laserCapability = argsPack.laserCapability
                                    }
                                }

                                SendMessageForRangeReference(onlineGroupController.groupName .. ":开始激光照射"
                                    , 5, onlineGroupController:getRangeReference())
                                timer.scheduleFunction(FunctionPackerAndCaller, functionPack
                                    , timer.getTime() + 0.241)
                            else
                                argsPack.laserCapability.switch = -1
                            end
                        end
                    end

                    function onlineGroupController:artilleryShelling(argsPack)
                        local point = onlineGroupController:getSPIVec3()
                        if point == nil then
                            return nil
                        end

                        --DXbugMessage(512)
                        --DXbugMessage(215)

                        local engage = {
                            id = "FireAtPoint",
                            params = {
                                point = mist.utils.makeVec2(point),
                                expendQty = argsPack.shellingParams.expendQty,
                                expendQtyEnabled = true,
                                weaponType = argsPack.shellingParams.weaponType
                            }
                        }
                        --DXbugMessage(216)

                        if onlineGroupController:isMissionEnable() ~= nil then
                            --DXbugMessage(217)
                            SendMessageForRangeReference(onlineGroupController.groupName .. ":正在攻击", 5,
                                onlineGroupController:getRangeReference())
                            onlineGroupController.group:getController():pushTask(engage)
                        end
                    end
                end

                --配置函数包
                --所有的能力配置都必须任务一开始就配置好，但是你可以选择这个能力在游戏过程中何时可用何时不可用
                do
                    --标准的侦查能力
                    function onlineGroupController.Public:initAreaRecon(reconCapability)
                        local data = {
                            text = onlineGroupController.groupName .. ":实施区域侦查",
                            commandFunction = onlineGroupController.areaRecon,
                            argsPack = {
                                theCallerSelf = onlineGroupController
                            }
                        }

                        onlineGroupController.reconCapability = reconCapability
                        --DXbugMessage(41)
                        onlineGroupController:dirInsertCapabilityNode(data, true)
                        --DXbugMessage(42)
                    end

                    --标准的高空水平定点轰炸，实施这种任务需要群组可以设置“执行任务-轰炸”这一航路点动作,bombingParams的缺省值和原型详见定义内
                    function onlineGroupController.Public:initHighAltitudeHorizontalBombing(bombingParams)
                        local localBombingParams = {
                            weaponType = nil,
                            expend = AI.Task.WeaponExpend["ONE"],
                            groupAttack = false,
                            altitude = mist.utils.feetToMeters(30000),
                            altitudeEnabled = true
                        }
                        do
                            if bombingParams ~= nil then
                                if bombingParams.weaponType ~= nil then
                                    localBombingParams.weaponType = bombingParams.weaponType
                                end
                                if bombingParams.expend ~= nil then
                                    localBombingParams.expend = bombingParams.expend
                                end
                                if bombingParams.groupAttack ~= nil then
                                    localBombingParams.groupAttack = bombingParams.groupAttack
                                end
                                if bombingParams.altitude ~= nil then
                                    localBombingParams.altitude = bombingParams.altitude
                                end
                                if bombingParams.altitudeEnabled ~= nil then
                                    localBombingParams.altitudeEnabled = bombingParams.altitudeEnabled
                                end
                            end
                        end

                        local data = {
                            text = onlineGroupController.groupName .. ":定点攻击",
                            commandFunction = onlineGroupController.highAltitudeHorizontalBombing,
                            argsPack = {
                                theCallerSelf = onlineGroupController,
                                bombingParams = localBombingParams
                            }
                        }

                        onlineGroupController:dirInsertCapabilityNode(data, true)
                    end

                    --近距离搜索和猎歼，实施这种任务需要群组可以设置“开始在航任务-搜索并攻击区域内目标”这一航路点动作，zoneRadius是其围绕SPI搜索猎歼的半径，缺省值800
                    function onlineGroupController.Public:initSearchAndHunting(zoneRadius)
                        local localZoneRadius = 800
                        if zoneRadius ~= nil then
                            localZoneRadius = zoneRadius
                        end

                        local data = {
                            text = onlineGroupController.groupName .. ":搜索猎歼",
                            commandFunction = onlineGroupController.searchAndHunting,
                            argsPack = {
                                theCallerSelf = onlineGroupController,
                                zoneRadius = localZoneRadius
                            }
                        }

                        onlineGroupController:dirInsertCapabilityNode(data, true)
                    end

                    --进行激光照射指示的能力，distanceLimitation不填默认40km，laserCode不填默认1688，overHeatedTime不填默认60
                    function onlineGroupController.Public:initLaserSpotting(distanceLimitation, laserCode, overHeatedTime)
                        local localDistanceLimitation = 40000
                        local localLaserCode = 1688
                        local localOverHeatedTime = 60
                        if distanceLimitation ~= nil then
                            localDistanceLimitation = distanceLimitation
                        end
                        if laserCode ~= nil then
                            localLaserCode = laserCode
                        end
                        if overHeatedTime ~= nil then
                            localOverHeatedTime = overHeatedTime
                        end

                        local data = {
                            text = onlineGroupController.groupName .. ":开关激光照射",
                            commandFunction = onlineGroupController.laserSpotting,
                            argsPack = {
                                theCallerSelf = onlineGroupController,
                                laserCapability = {
                                    switch = -1, --开关标志，在laserSpotting和refreshLaserSpot里用来控制循环启停用的域
                                    distanceLimitation = localDistanceLimitation, --距离限制
                                    laserCode = localLaserCode,
                                    overHeatedTime = localOverHeatedTime
                                }
                            }
                        }

                        onlineGroupController:dirInsertCapabilityNode(data, true)
                    end

                    --地面群组和舰船所使用的能力，相当于编辑器里的“向指定点开火”
                    function onlineGroupController.Public:initArtilleryShelling(shellingParams)
                        --DXbugMessage(213)
                        local localShellingParams = {
                            weaponType = nil,
                            expendQty = 1
                        }
                        do
                            if shellingParams ~= nil then
                                if shellingParams.weaponType ~= nil then
                                    localShellingParams.weaponType = shellingParams.weaponType
                                end
                                if shellingParams.expendQty ~= nil then
                                    localShellingParams.expendQty = shellingParams.expendQty
                                end
                            end
                        end

                        local data = {
                            text = onlineGroupController.groupName .. ":炮击",
                            commandFunction = onlineGroupController.artilleryShelling,
                            argsPack = {
                                theCallerSelf = onlineGroupController,
                                shellingParams = localShellingParams
                            }
                        }

                        onlineGroupController:dirInsertCapabilityNode(data, true)
                        --DXbugMessage(214)
                    end
                end

                return onlineGroupController
            end
        end

        LinkPad = {}

        function LinkPad.New(initedRangeReference, groupNameWaitForPlayerToEnter) --定义时只要传进来这个pad属于谁就好啦，注意一个Pad一旦new出来就会连带把这个rangeReference对应的commandTree给new出来，小心冲突
            local linkPad = {}
            linkPad.Public = {}
            linkPad.onlineGroupControllers = nil --链表{data,next},data保存在链群组控制器

            --声明函数
            do
                --一些工具
                do
                    function linkPad:initMyself(rangeReference)
                        linkPad.rangeReference = {
                            range = rangeReference.range, --0全体，1阵营，2群组
                            reference = rangeReference.reference --range==1时为coalition.side，range==2时为group对象
                        }
                        linkPad.targetsManagement = TargetsManagement.New(linkPad)
                        linkPad.commandTree = CommandTree.New(linkPad.rangeReference)

                        linkPad.setSPIByUserMarkCommandNode = CommandNode.NewByArgsPack("选择地图标记", true,
                            linkPad.targetsManagement.setSPIByUserMark, { theCallerSelf = linkPad.targetsManagement })
                        linkPad.autoSetSPIByUserMarkCommandNode = CommandNode.NewByArgsPack("切换自动跟踪地图标记"
                            ,
                            true,
                            linkPad.targetsManagement.switchAutoSetSPIByUserMark,
                            { theCallerSelf = linkPad.targetsManagement })

                        linkPad.targetsSelectorCommandNode = CommandNode.New("选择侦查到的目标", false)

                        linkPad.actionControlCommandNode = CommandNode.New("行动控制菜单", false)

                        --临时，等加了节点锁定功能后要删掉
                        do
                            linkPad.displayLockerSwitch = false

                            linkPad.switchDisplayLocker = function()
                                if linkPad.displayLockerSwitch then
                                    linkPad.commandTree:setDisplayLockerCommandNode(nil)
                                    linkPad.displayLockerSwitch = false
                                else
                                    linkPad.commandTree:setDisplayLockerCommandNode(linkPad.commandTree.rootNode)
                                    linkPad.displayLockerSwitch = true
                                end
                            end

                            linkPad.switchDisplayLockerControlCommandNode = CommandNode.NewByArgsPack("切换锁定显示本菜单"
                                , true, linkPad.switchDisplayLocker, { theCallerSelf = linkPad })
                        end

                        linkPad.commandTree:addNode(linkPad.commandTree.rootNode, linkPad.setSPIByUserMarkCommandNode)
                        linkPad.commandTree:addNode(linkPad.commandTree.rootNode, linkPad.autoSetSPIByUserMarkCommandNode)
                        linkPad.commandTree:addNode(linkPad.commandTree.rootNode, linkPad.targetsSelectorCommandNode)
                        linkPad.commandTree:addNode(linkPad.commandTree.rootNode, linkPad.actionControlCommandNode)

                        linkPad.commandTree:addNode(linkPad.commandTree.rootNode,
                            linkPad.switchDisplayLockerControlCommandNode)
                        --linkPad.commandTree:setDisplayLockerCommandNode(linkPad.commandTree.rootNode)
                    end
                end

                --预定义警告函数包
                do
                    function linkPad:SPINotExistWarnMessage()
                        SendMessageForRangeReference("尚未设置SPI,请先设置一个SPI", 5,
                            linkPad.rangeReference)
                    end
                end

                --管理在链群组控制器
                do
                    function linkPad:implementMissionCapability(missionCapability)
                        --清理trashBin
                        if missionCapability.trashBin ~= nil then
                            --DXbugMessage(2)
                            linkPad.commandTree:deleteSubTree(missionCapability.trashBin)
                        end

                        --DXbugMessage(43)
                        --装填新commandNode
                        if missionCapability.enable and
                            (missionCapability.head.enable == false or missionCapability == missionCapability.head) then
                            local commandNode = CommandNode.NewByArgsPack(missionCapability.data.text, true,
                                missionCapability.data.commandFunction,
                                missionCapability.data.argsPack)

                            --DXbugMessage(45)
                            linkPad.commandTree:addNode(linkPad.actionControlCommandNode, commandNode)

                            missionCapability.trashBin = commandNode
                        end
                    end

                    function linkPad:implementOnlineGroupController(onlineGroupController)
                        --DXbugMessage(1)
                        do
                            local i = onlineGroupController.missionCapability
                            while i ~= nil do
                                linkPad:implementMissionCapability(i)
                                i = i.next
                            end
                        end

                    end

                    function linkPad:dirInsertOnlineGroupController(onlineGroupController, ifRadioReport)
                        if onlineGroupController.masterLinkPad ~= linkPad then
                            return nil
                        end

                        if onlineGroupController:isMissionEnable() == nil then
                            return nil
                        end

                        --DXbugMessage(" " .. onlineGroupController.groupName)

                        if ifRadioReport then
                            local msg = ""
                            msg = msg .. onlineGroupController.groupName .. ":现已移交你部指挥"
                            SendMessageForRangeReference(msg, 5, linkPad.rangeReference)
                        end

                        linkPad:implementOnlineGroupController(onlineGroupController)
                    end

                    function linkPad.Public:insertOnlineGroupController(onlineGroupController, ifRadioReport) --ifRadioReport控制是否显式地报告控制权移交，不填默认不报

                        onlineGroupController.masterLinkPad = linkPad
                        local node = {
                            data = onlineGroupController,
                            next = linkPad.onlineGroupControllers
                        }
                        linkPad.onlineGroupControllers = node

                        if linkPad.groupNameWaitForPlayerToEnter ~= nil then
                            linkPad:insertRecallNode(linkPad.dirInsertOnlineGroupController,
                                onlineGroupController, ifRadioReport)
                            return nil
                        end

                        linkPad:dirInsertOnlineGroupController(onlineGroupController, ifRadioReport)
                    end

                end

                do
                    function linkPad:eyesOnTarget(argsPack)
                        local targetUnit = argsPack.targetUnit
                        local trackerUnit = argsPack.trackerUnit

                        if TryWithoutObjectNilException.IsTargetDetectedAndVisible(trackerUnit, targetUnit) then
                            linkPad.targetsManagement:setSPIByVec3(TryWithoutObjectNilException.UnitGetPoint(targetUnit))
                        else
                            SendMessageForRangeReference("失去跟踪，SPI已记录最后已知位置", 5,
                                linkPad.rangeReference)
                            linkPad.targetsManagement:stopTracking()
                        end
                    end

                    function linkPad:startTracking(argsPack)
                        SendMessageForRangeReference(argsPack.trackerUnit:getName() ..
                            ":正在跟踪SPI:" .. argsPack.targetUnit:getTypeName(), 5, linkPad.rangeReference)

                        linkPad.commandTree:deleteChildren(linkPad.targetsSelectorCommandNode)
                        linkPad.targetsManagement:setTrackingFunction(linkPad.eyesOnTarget, argsPack)
                    end

                    function linkPad:uploadTargets(targets, uploaderOnlineGroupController, uploaderUnit)
                        linkPad.commandTree:deleteChildren(linkPad.targetsSelectorCommandNode)

                        local commandNodes = {}
                        do
                            local i = 1
                            while targets[i] ~= nil do
                                local text = uploaderOnlineGroupController.groupName ..
                                    ":选择 " .. targets[i].object:getTypeName()
                                local argsPack = {
                                    theCallerSelf = linkPad,
                                    targetUnit = targets[i].object,
                                    trackerUnit = uploaderUnit
                                }
                                --SendMessageForRangeReference("startSending"..i,5)
                                commandNodes[i] = CommandNode.NewByArgsPack(text, true, linkPad.startTracking, argsPack)

                                i = i + 1
                            end
                        end

                        linkPad.commandTree:addNodes(linkPad.targetsSelectorCommandNode, commandNodes)
                    end
                end
            end

            --全部声明完成，开始初始化
            do
                if groupNameWaitForPlayerToEnter ~= nil then
                    linkPad.groupNameWaitForPlayerToEnter = groupNameWaitForPlayerToEnter

                    linkPad.recallLinkList = {
                        ahead = nil,
                        myFunction = nil,
                        myxArgs = nil,
                        next = {
                            ahead = linkPad.recallLinkList,
                            myFunction = nil,
                            myxArgs = nil,
                            next = nil
                        }
                    }

                    function linkPad:insertRecallNode(myFunction, ...) --返回的是recallNode的索引，保存以用于delete节点
                        local recallNode = {
                            ahead = linkPad.recallLinkList,
                            myFunction = myFunction,
                            myxArgs = { ... },
                            next = linkPad.recallLinkList.next
                        }

                        linkPad.recallLinkList.next = recallNode
                        recallNode.next.ahead = recallNode
                        return recallNode
                    end

                    function linkPad:justDoIt()
                        do
                            --DXbugMessage(11)
                            local currentRecallNode = linkPad.recallLinkList.next
                            while currentRecallNode.myFunction ~= nil do
                                currentRecallNode = currentRecallNode.next
                            end
                            currentRecallNode = currentRecallNode.ahead

                            while currentRecallNode.myFunction ~= nil do
                                --DXbugMessage(45)
                                currentRecallNode.myFunction(linkPad, unpack(currentRecallNode.myxArgs))
                                --DXbugMessage(14)
                                currentRecallNode = currentRecallNode.ahead
                            end
                        end

                        linkPad.recallLinkList = nil
                        linkPad.insertRecallNode = nil
                    end

                    linkPad.waitForPlayerToEnterEventHandler = {}
                    function linkPad.waitForPlayerToEnterEventHandler:onEvent(event)
                        if event.id == 20 then
                            if event.initiator:getGroup():getName() == linkPad.groupNameWaitForPlayerToEnter then
                                local rangeReference = {
                                    range = 2,
                                    reference = event.initiator:getGroup()
                                }
                                linkPad.groupNameWaitForPlayerToEnter = nil
                                --DXbugMessage(114514)
                                linkPad:initMyself(rangeReference)
                                linkPad:justDoIt()
                                linkPad.justDoIt = nil
                                world.removeEventHandler(linkPad.waitForPlayerToEnterEventHandler)
                            end
                        end
                    end

                    world.addEventHandler(linkPad.waitForPlayerToEnterEventHandler)
                else
                    linkPad:initMyself(initedRangeReference)
                end
            end

            return linkPad
        end
    end
end
