{
  inputs,
  ...
}:

{
  imports = [ inputs.nixcord.homeModules.nixcord ];

  programs.nixcord = {
    enable = true;

    discord.enable = false;
    equibop.enable = true;

    userPlugins = {
      eval = inputs.equi-eval;
      venfetch = inputs.equi-venfetch;
      clientsidebadges = inputs.equi-clientsidebadges;
      rebuildandrestart = ./plugins/rebuildAndRestart;
    };

    config = {
      enabledThemeLinks = [
        "https://raw.githubusercontent.com/rose-pine/discord/refs/heads/main/dist/rose-pine-moon.css"
      ];
      transparent = true;
      enableReactDevtools = true;
      plugins = {
        advancedPermissions.enable = true;
        alwaysAnimate.enable = true;
        atSomeone.enable = true;
        betterAudioPlayer.enable = true;
        betterFolders.enable = true;
        betterForwards.enable = true;
        betterGifAltText.enable = true;
        betterSessions.enable = true;
        betterSettings.enable = true;
        callTimer.enable = true;
        cancelFriendRequest.enable = true;
        channelTabs = {
          rapidNavigationThreshold = 3000.0;
          tabWidthScale = 50;
        };
        characterCounter.enable = true;
        clearUrls.enable = true;
        clickableRoles.enable = true;
        colorSighted.enable = true;
        commandPalette = {
          enable = true;
          hotkey = [
            "Control"
            "Shift"
            "P"
          ];
        };
        concatenatedComponentExtractor.enable = true;
        concatenatedModules.enable = true;
        consoleJanitor.enable = true;
        consoleShortcuts.enable = true;
        copyFileContents.enable = true;
        copyStickerLinks.enable = true;
        crashHandler.enable = true;
        declutter = {
          enable = true;
          removeShopAboveDms = true;
        };
        decor.enable = true;
        devCompanion.enable = true;
        disableDeepLinks.enable = true;
        downloadAllAttachments.enable = true;
        equicordHelper = {
          enable = true;
          disableAdoptTagPrompt = true;
        };
        equicordToolbox.enable = true;
        experiments = {
          enable = true;
          toolbarDevMenu = true;
        };
        expressionCloner.enable = true;
        fakeNitro = {
          enable = true;
          enableStreamQualityBypass = false;
        };
        fakeProfileThemes.enable = true;
        favouriteAnything.enable = true;
        fileUpload = {
          enable = true;
          serviceType = "catbox";
          autoSend = true;
          fallbackOrder = "catbox,litterbox,gofile,zipline,ezhost,nest,s3,0x0,tmpfiles,buzzheavier,tempsh,filebin,pixelvault,pixeldrain,sharex";
        };
        fixFileExtensions.enable = true;
        fixImagesQuality.enable = true;
        fixSpotifyEmbeds.enable = true;
        friendCodes.enable = true;
        fullVcpfp.enable = true;
        gifMaker.enable = true;
        gifPaste.enable = true;
        gitHubRepos.enable = true;
        globalBadges.enable = true;
        googleThat.enable = true;
        hideMessages.enable = true;
        imageFilename.enable = true;
        imageZoom.enable = true;
        invisibleChat.enable = true;
        loginWithQr.enable = true;
        markdownTables.enable = true;
        mediaPlaybackSpeed.enable = true;
        memberCount.enable = true;
        mentionAvatars.enable = true;
        messageClickActions = {
          enable = true;
          enableDoubleClickToEdit = false;
          doubleClickAction = "EDIT";
          tripleClickAction = "REACT";
          deferDoubleClickForTriple = true;
        };
        messageColors = {
          enable = true;
          renderType = 0;
        };
        messageFetchTimer.enable = true;
        messageLatency.enable = true;
        messageLinkEmbeds.enable = true;
        messageLogger.enable = true;
        messageLoggerEnhanced = {
          enable = true;
          imageCacheDir = "/home/chaos/.config/equibop/MessageLoggerData/savedImages";
          logsDir = "/home/chaos/.config/equibop/MessageLoggerData";
          attachmentFileExtensions = "none";
        };
        messagePeek.enable = true;
        moreCommands = {
          enable = true;
          addFreakyEnding = true;
        };
        moreStickers = {
          enable = true;
          promptToUpload = true;
        };
        newPluginsManager.enable = true;
        noDevtoolsWarning.enable = true;
        noTrack.enable = true;
        permissionFreeWill.enable = true;
        permissionsViewer.enable = true;
        petpet.enable = true;
        previewMessage.enable = true;
        questify = {
          enable = true;
          questButtonBadgeCount = 11;
          acknowledgedNotices = {
            quest-ban-warning-2026-08-07 = true;
          };
        };
        quoter.enable = true;
        reactErrorDecoder.enable = true;
        readAllNotificationsButton.enable = true;
        repeatMessages.enable = true;
        replyTimestamp.enable = true;
        reverseImageSearch.enable = true;
        reviewDb.enable = true;
        searchFix.enable = true;
        sedEnhanced = {
          enable = true;
          regexByDefault = true;
        };
        sendTimestamps.enable = true;
        serverInfo.enable = true;
        serverListIndicators.enable = true;
        serverSearch.enable = true;
        settings.enable = true;
        shikiCodeblocks = {
          enable = true;
          theme = "https://cdn.jsdelivr.net/gh/shikijs/textmate-grammars-themes@bc5436518111d87ea58eb56d97b3f9bec30e6b83/packages/tm-themes/themes/rose-pine-moon.json";
          useDevIcon = "COLOR";
        };
        showConnections.enable = true;
        showHiddenChannels.enable = true;
        showHiddenThings.enable = true;
        showMessageEmbeds.enable = true;
        showSongName.enable = true;
        showTimeoutDuration.enable = true;
        sidebarChat.enable = true;
        silenceUsers.enable = true;
        silentMessageToggle = {
          enable = true;
          persistState = "none";
        };
        silentTyping = {
          enable = true;
          showIcon = true;
        };
        splitLargeMessages.enable = true;
        spotifyCrack.enable = true;
        startupTimings.enable = true;
        stopAutoUnread.enable = true;
        summaries.enable = true;
        supportHelper.enable = true;
        talkInReverse.enable = true;
        tenorGifSearch.enable = true;
        themeAttributes.enable = true;
        timezones = {
          enable = true;
          askedTimezone = true;
        };
        translate = {
          enable = true;
          sentOutput = "de";
        };
        translatePlus.enable = true;
        triviaAi = {
          systemPrompt = "You are a helpful assistant who answers questions for the user in a concise and short way while using the least amount of words and punctuation.";
        };
        typingIndicator.enable = true;
        typingTweaks = {
          enable = true;
          amITyping = true;
        };
        unitConverter.enable = true;
        unlimitedAccounts.enable = true;
        unlockedAvatarZoom.enable = true;
        unreadCountBadge.enable = true;
        unsuppressEmbeds.enable = true;
        userpluginInstaller.enable = true;
        vcPanelSettings.enable = true;
        viewIcons.enable = true;
        viewRaw.enable = true;
        voiceChannelLog.enable = true;
        voiceChatUtilities.enable = true;
        voiceDownload.enable = true;
        voiceMessages.enable = true;
        voiceStats.enable = true;
        volumeBooster.enable = true;
        webContextMenus.enable = true;
        webKeybinds = {
          enable = true;
          overrideCommonKeybinds = true;
        };
        webScreenShareFixes.enable = true;
        whoReacted.enable = true;
        whosWatching.enable = true;
        youtubeAdblock.enable = true;
        zipPreview.enable = true;
      };
    };
    extraConfig.plugins = {
      eval.enable = true;
      clientsidebadges.enable = true;
      venfetch.enable = true;
      rebuildandrestart.enable = true;
      Anammox = {
        enable = true;
        dms = true;
        billing = true;
        gift = true;
        emojiList = true;
        gif = false;
        serverBoost = true;
        quests = false;
      };
      AntiRickroll = {
        enable = true;
        customLinks = "";
        customVideoIds = "";
      };
      betterAudioPlayer = {
        forceMoveBelow = true;
      };
      betterFolders = {
        nestedFolders = { };
        enableNestedFolders = true;
      };
      BetterForums = {
        keepState = true;
        showFollowButton = true;
        maxTagCount = 3;
        messagePreviewLineCount = 3;
        useExactCounts = true;
        showThreadMembers = true;
        showReplyPreview = 1;
        highlightNewMessages = false;
        maxReactionCount = 3;
        tagOverrides = {
          archived = {
            disabled = false;
          };
        };
        maxMediaCount = 3;
        mediaSize = 72;
      };
      BetterGifLoad = {
        enable = true;
        gifQuality = 1;
      };
      BigFileUpload = {
        enable = true;
        fileUploader = "Catbox";
        customUploaderName = "";
        customUploaderRequestURL = "";
        customUploaderFileFormName = "";
        customUploaderResponseType = "Text";
        customUploaderURL = "";
        customUploaderThumbnailURL = "";
        customUploaderHeaders = "{}";
        customUploaderArgs = "{}";
        autoSend = "No";
        autoFormat = "No";
        catboxUserHash = "";
      };
      characterCounter = {
        position = false;
      };
      ChineseWhispers = {
        intensity = 108;
        shuffle = true;
        presend = false;
      };
      ClientSideBadges = {
        enable = true;
        orbs = true;
        aClownForATime = true;
        nitroPlatinum = true;
        discordStaff = true;
        partneredServerOwner = true;
        earlySupporter = true;
        activeDeveloper = true;
        earlyVerifiedBotDeveloper = true;
        moderatorProgramsAlumni = true;
        bugHunter = true;
        goldenBugHunter = true;
        hypesquadEvents = true;
        houseOfBravery = true;
        houseOfBrilliance = true;
        houseOfBalance = true;
        discordQuests = true;
        nitro = true;
        nitroBronze = true;
        nitroSilver = true;
        nitroGold = true;
        nitroOpal = true;
        nitroRuby = true;
        nitroEmerald = true;
        nitroDiamond = true;
        legacyUsername = true;
        m1serverBooster = true;
        m2serverBooster = true;
        m3serverBooster = true;
        m6serverBooster = true;
        m9serverBooster = true;
        m12serverBooster = true;
        m15serverBooster = true;
        m18serverBooster = true;
        m24serverBooster = true;
        supportsCommands = true;
        usesAutomod = true;
        premiumApp = true;
      };
      CollapseChatButtons = {
        enable = true;
        Open = false;
        ExcludedButtons = "submit;";
      };
      collapsibleUi = {
        transitionMs = 160;
      };
      commandPalette = {
        allowMouseControl = true;
        visualStyle = "classic";
        showTags = true;
        enableTagFilter = true;
      };
      declutter = {
        removeUsernameStyles = true;
      };
      Demonstration = {
        enable = true;
        keyBind = "F6";
      };
      EnableStereo = {
        enable = true;
        stereochannel = 7.1;
      };
      equicordHelper = {
        disableDMContextMenu = false;
        noDefaultHangStatus = false;
      };
      FakeBadges = {
        enable = true;
        discordStaffBadge = true;
        activeDeveloperBadge = true;
        hypeSquadEventsBadge = true;
        moderatorProgrammesAlumniBadge = true;
        partneredServerOwnerBadge = true;
        earlySupporterBadge = true;
        earlyVerifiedBotDeveloperBadge = true;
        discordBugHunterGoldBadge = true;
        discordBugHunterGreenBadge = true;
        nitroMemberBadge = true;
        boostingBadge = 9;
      };
      FavoriteGifSearch = {
        enable = true;
        searchOption = "hostandpath";
      };
      fileUpload = {
        interceptDiscordUpload = false;
      };
      gitHubRepos = {
        showRepositoryTab = true;
        showInMiniProfile = true;
      };
      globalBadges = {
        showPrefix = true;
        showSuffix = false;
      };
      ImagePreview = {
        messageImages = true;
        messageAvatars = true;
        messageLinks = true;
        messageStickers = true;
        mouseOnlyMode = false;
        fixedImage = false;
        fileInformation = true;
        hoverDelay = 0.5;
        zoomFactor = 1.5;
        defaultMaxSize = "0";
      };
      JSTextReplace = {
        enable = true;
        hasDoneChallenge = true;
        rules = [
          {
            find = "";
            replace = "";
            onlyIfIncludes = "";
          }
        ];
      };
      messageClickActions = {
        backspaceClickAction = "delete";
        keySelection = "backspace";
      };
      messageLoggerEnhanced = {
        autoCheckForUpdates = true;
      };
      OCR = {
        enable = true;
        engine = 2;
      };
      quoter = {
        userIdentifier = 0;
      };
      RandomGary = {
        enable = true;
        randomGaryImageSource = "gary";
        randomGarySendMethod = "link";
      };
      ReactionLogger = {
        enable = true;
        ignoreSelf = true;
        delay = 15;
      };
      Remind = {
        enable = true;
        remindInterval = 60;
      };
      Search = {
        customSearchEngine = "example.com";
      };
      "Sekai Stickers" = {
        enable = true;
        checkForUpdateOnStartUp = true;
        AutoCloseModal = true;
      };
      SentFromMyUname = {
        signatureToUse = "uname";
      };
      showMeYourName = {
        ignoreEffects = true;
        animateEffects = false;
      };
      ShowPing = {
        enable = true;
        showNearbyConnectionStatus = false;
        showUnderConnectionIcon = true;
      };
      sidebarChat = {
        patchCommunity = true;
      };
      silentTyping = {
        specificChats = false;
        disabledFor = "";
      };
      SortForumsByUnread = {
        enable = true;
        sortByUnread = true;
      };
      SoundBoardLogger = {
        enable = true;
        IconLocation = "toolbar";
        FileType = ".ogg";
      };
      SpotifyLyrics = {
        enable = true;
        ShowMusicNoteOnNoLyrics = true;
        LyricsPosition = "below";
        LyricsProvider = "Spotify";
        FallbackProvider = true;
        TranslateTo = "en";
        LyricsConversion = "None";
        ShowFailedToasts = true;
        LyricDelay = -1250;
      };
      SpotiMbed = {
        enable = true;
        colorStyle = "pastel";
        forceStyle = 0.5;
        volume = 0.5;
        market = "US";
        nativeLinks = false;
        numericMonth = false;
      };
      Timezone = {
        enable = true;
        showMessageHeaderTime = true;
        showProfileTime = true;
      };
      translate = {
        showChatBarButton = true;
      };
      triviaAi = {
        autoRespond = false;
      };
      unreadCountBadge = {
        replaceWhiteDot = false;
      };
      voiceChannelLog = {
        voiceChannelChatSelf = true;
        voiceChannelChatSilent = true;
        voiceChannelChatSilentSelf = false;
      };
    };
  };
}
