do
    --获取你在任务编辑器中创建的组群并对象化，如果你像这个sample一样用getByName获取组群对象的话，你必须保证getByName的参数和你在任务编辑器里给组群起的名字一样
    local reconGroup = Group.getByName("侦察机") --获取这个组群对象
    local attackerGroup = Group.getByName("攻击机") --获取这个组群对象
    local bomberGroup = Group.getByName("轰炸机") --获取这个组群对象

    local playerGroup=Group.getByName("134th kiap") --获取这个组群对象

    --设置一些待会需要用到的常量
    local rangeReference = { --定义控制权
        range = 2,--填1说明控制权属于某一阵营，填2说明控制权属于某一组群
        reference = playerGroup--如果你第一行填的range=1,你应该在这里填写reference=coalition.side["RED"]或reference=coalition.side["BLUE"]
    }
    local reconCapability = { --定义探测能力,这是initAreaRecon所需要的参数，单位都是米
        distance = 200000,--能探测到多远的目标？
        radius = 5000--一次探测能探测以探测点为中心，多大半径内的范围？
    }

    --如果你创建的这个数据链实例的控制权属于一个“客户端”组群，你必须填写New中的第二个参数（这个组群的名称）
    --相反地，如果控制权属于一个单人游戏中的“玩家”组群，或者控制权属于某一阵营，必须不填写第二个参数，只传递rangeReference一个参数进去
    --这个特性跟客户端组群的一些特殊性质有关，可能很快在未来版本中简化配置方法（等我把客户端组群的性质测清楚）
    PublicLinkPad = LinkPad.New(rangeReference,"134th kiap") --创建数据链实例，定义这个数据链的控制权属于谁

    --下面是创建和移交数据链控制器
    --AI以组群为单位受支配和控制，如果你希望某个AI组群接受支配，应该在这里创建好它的数据链控制器
    local reconGroupController = OnlineGroupController.New(reconGroup) --创建reconGroup的数据链控制器
    reconGroupController.Public:initAreaRecon(reconCapability) --向控制器声明该组群有区域侦查能力
    reconGroupController.Public:initLaserSpotting(nil,1688,180)

    PublicLinkPad.Public:insertOnlineGroupController(reconGroupController) --向数据链实例移交该控制器

    PublicAttackerGroupController = OnlineGroupController.New(attackerGroup)
    PublicAttackerGroupController.Public:initSearchAndHunting()
    PublicLinkPad.Public:insertOnlineGroupController(PublicAttackerGroupController)

    PublicBomberGroupController=OnlineGroupController.New(bomberGroup)
    PublicBomberGroupController.Public:initHighAltitudeHorizontalBombing()
    PublicLinkPad.Public:insertOnlineGroupController(PublicBomberGroupController)

    --上述代码执行完毕后，“134th kiap”这个组群成为一个数据链的控制组群，这个数据链中的受控AI组群为名为“侦察机”、“攻击机”、“轰炸机”的三个组群，分别可以执行侦查和照射激光、猎歼地面单位、高空水平轰炸任务
end
