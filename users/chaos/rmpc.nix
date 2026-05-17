{
  ...
}:

{
  config = {
    home.file.".config/mpd/mpd.conf".text = ''
      music_directory    "~/Music"
      playlist_directory "~/.local/share/mpd/playlists"
      db_file            "~/.local/share/mpd/database"
      pid_file           "~/.local/share/mpd/pid"
      log_file           "/dev/null"
      state_file         "~/.local/share/mpd/state"

      bind_to_address    "/tmp/mpd_socket"

      audio_output {
          type           "pipewire"
          name           "PipeWire Output"
      }
    '';
    home.file.".config/rmpc/config.ron".text = ''
                          #![enable(implicit_some)]
                          #![enable(unwrap_newtypes)]
                          #![enable(unwrap_variant_newtypes)]
                          (
                              address: "/tmp/mpd_socket",
                              password: None,
                              theme: "def",
                              cache_dir: None,
                              on_song_change: None,
                              volume_step: 5,
                              max_fps: 60,
                              scrolloff: 2,
                              wrap_navigation: true,
                              enable_mouse: true,
                              scroll_amount: 1,
                              enable_config_hot_reload: true,
                              enable_lyrics_hot_reload: false,
                              status_update_interval_ms: 1000,
                              rewind_to_start_sec: None,
                              keep_state_on_song_change: true,
                              reflect_changes_to_playlist: false,
                              select_current_song_on_change: false,
                              ignore_leading_the: false,
                              browser_song_sort: [Disc, Track, Artist, Title],
                              directories_sort: SortFormat(group_by_type: true, reverse: false),
                              auto_open_downloads: true,
                              album_art: (
                                  method: Auto,
                                  max_size_px: (width: 1200, height: 1200),
                                  disabled_protocols: ["http://", "https://"],
                                  vertical_align: Center,
                                  horizontal_align: Center,
                              ),
                  						cava: (
                        			    framerate: 60,
                        			    autosens: true,
                        			    sensitivity: 130,
      														input: (
              										    method: Pipewire,
              										    source: "auto",
              										),
                        			    smoothing: (
                        			        noise_reduction: 25,
                        			        monstercat: false,
                        			        waves: false,
                        			    ),
                        			),
                              keybinds: (
                                  global: {
                                      "q":          Quit,
                                      "?":          ShowHelp,
                                      ":":          CommandMode,
                                      "oI":         ShowCurrentSongInfo,
                                      "oo":         ShowOutputs,
                                      "op":         ShowDecoders,
                                      "od":         ShowDownloads,
                                      "oP":         Partition(),
                                      "z":          ToggleRepeat,
                                      "x":          ToggleRandom,
                                      "c":          ToggleConsume,
                                      "v":          ToggleSingle,
                                      "p":          TogglePause,
                                      "s":          Stop,
                                      ">":          NextTrack,
                                      "<":          PreviousTrack,
                                      "f":          SeekForward,
                                      "b":          SeekBack,
                                      ".":          VolumeUp,
                                      ",":          VolumeDown,
                                      "<Tab>":      NextTab,
                                      "gt":         NextTab,
                                      "<S-Tab>":    PreviousTab,
                                      "gT":         PreviousTab,
                                      "1":          SwitchToTab("Queue"),
                                      "2":          SwitchToTab("Directories"),
                                      "3":          SwitchToTab("Artists"),
                                      "4":          SwitchToTab("Album Artists"),
                                      "5":          SwitchToTab("Albums"),
                                      "6":          SwitchToTab("Playlists"),
                                      "7":          SwitchToTab("Search"),
                                      "<C-u>":      Update,
                                      "<C-U>":      Rescan,
                                      "R":          AddRandom,
                                  },
                                  navigation: {
                                      "<C-c>":      Close,
                                      "<Esc>":      Close,
                                      "<CR>":       Confirm,
                                      "k":          Up,
                                      "<Up>":       Up,
                                      "j":          Down,
                                      "<Down>":     Down,
                                      "h":          Left,
                                      "<Left>":     Left,
                                      "l":          Right,
                                      "<Right>":    Right,
                                      "<C-w>k":     PaneUp,
                                      "<C-Up>":     PaneUp,
                                      "<C-w>j":     PaneDown,
                                      "<C-Down>":   PaneDown,
                                      "<C-w>h":     PaneLeft,
                                      "<C-Left>":   PaneLeft,
                                      "<C-w>l":     PaneRight,
                                      "<C-Right>":  PaneRight,
                                      "K":          MoveUp,
                                      "J":          MoveDown,
                                      "<C-u>":      UpHalf,
                                      "<C-d>":      DownHalf,
                                      "<C-b>":      PageUp,
                                      "<PageUp>":   PageUp,
                                      "<C-f>":      PageDown,
                                      "<PageDown>": PageDown,
                                      "gg":         Top,
                                      "G":          Bottom,
                                      "<Space>":    Select,
                                      "<C-Space>":  InvertSelection,
                                      "/":          EnterSearch,
                                      "n":          NextResult,
                                      "N":          PreviousResult,
                                      "a":          Add,
                                      "A":          AddAll,
                                      "D":          Delete,
                                      "<C-r>":      Rename,
                                      "i":          FocusInput,
                                      "oi":         ShowInfo,
                                      "<C-z>":      ContextMenu(),
                                      "<C-s>s":     Save(kind: Modal(all: false, duplicates_strategy: Ask)),
                                      "<C-s>a":     Save(kind: Modal(all: true, duplicates_strategy: Ask)),
                                      "r":          Rate(),
                                  },
                                  queue: {
                                      "d":          Delete,
                                      "D":          DeleteAll,
                                      "<CR>":       Play,
                                      "C":          JumpToCurrent,
                                      "X":          Shuffle,
                                  },
                              ),
                              search: (
                                  case_sensitive: false,
                                  ignore_diacritics: false,
                                  search_button: false,
                                  mode: Contains,
                                  tags: [
                                      (value: "any",         label: "Any Tag"),
                                      (value: "artist",      label: "Artist"),
                                      (value: "album",       label: "Album"),
                                      (value: "albumartist", label: "Album Artist"),
                                      (value: "title",       label: "Title"),
                                      (value: "filename",    label: "Filename"),
                                      (value: "genre",       label: "Genre"),
                                  ],
                              ),
                              artists: (
                                  album_display_mode: SplitByDate,
                                  album_sort_by: Date,
                                  album_date_tags: [Date],
                              ),
                              tabs: [
                                  (
                                      name: "Queue",
                                      pane: Split(
                                          direction: Horizontal,
                                          panes: [
                                              (
                                                  size: "35%",
                                                  pane: Split(
                                                      direction: Vertical,
                                                      panes: [
                                                          (
                                                              size: "100%",
                                                              borders: "LEFT | RIGHT | TOP",
                                                              border_symbols: Rounded,
                                                              pane: Pane(AlbumArt)
                                                          ),
                                                          (
                                                              size: "7",
                                                              borders: "ALL",
                                                              border_symbols: Inherited(parent: Rounded, top_left: "├", top_right: "┤",),
                                                              border_title: [(kind: Text(" Lyrics "))],
                                                              border_title_alignment: Right,
                                                              pane: Pane(Lyrics)
                                                          ),
                                                      ],
                                                  ),
                                              ), 
                                              (
                                                  size: "65%",
                                                  pane: Split(
                                                      direction: Vertical,
                                                      panes: [
                                                          (
                                                              size: "3",
                                                              borders: "ALL",
                                                              border_symbols: Inherited(parent: Rounded, bottom_left: "├", bottom_right: "┤",),
                                                              pane: Split(
                                                                  direction: Horizontal,
                                                                  panes: [
                                                                      (
                                                                          size: "1",
                                                                          pane: Pane(Empty())
                                                                      ),
                                                                      (
                                                                          size: "100%",
                                                                          pane: Pane(QueueHeader())
                                                                      ),
                                                                  ]
                                                              )
                                                          ),
                                                          (
                                                              size: "100%",
                                                              borders: "LEFT | RIGHT | BOTTOM",
                                                              border_symbols: Rounded,
                                                              pane: Split(
                                                                  direction: Vertical,
                                                                  panes: [
            																												(
                                                  									    size: "100%",
                                                  									    pane: Pane(Queue),
                                                  									),
                                                  									(
                                                  									    borders: "TOP",
                                                  									    size: "20",
                                                  									    pane: Pane(Cava)
                                                  									),
                                                                  ]
                                                              )
                                                          ),
                                                      ],
                                                  )
                                              ),
                                          ],
                                      ),
                                  ),
                                  (
                                      name: "Directories",
                                      borders: "ALL",
                                      border_symbols: Rounded,
                                      pane: Split(
                                          size: "100%",
                                          direction: Vertical,
                                          panes: [(pane: Pane(Directories), size: "100%", borders: "ALL", border_symbols: Rounded)],
                                      )
                                  ),
                                  (
                                      name: "Artists",
                                      borders: "ALL",
                                      border_symbols: Rounded,
                                      pane: Split(
                                          size: "100%",
                                          direction: Vertical,
                                          panes: [(pane: Pane(Artists), size: "100%", borders: "ALL", border_symbols: Rounded)],
                                      )
                                  ),
                                  (
                                      name: "Album Artists",
                                      borders: "ALL",
                                      border_symbols: Rounded,
                                      pane: Split(
                                          size: "100%",
                                          direction: Vertical,
                                          panes: [(pane: Pane(AlbumArtists), size: "100%", borders: "ALL", border_symbols: Rounded)],
                                      )
                                  ),
                                  (
                                      name: "Albums",
                                      borders: "ALL",
                                      border_symbols: Rounded,
                                      pane: Split(
                                          size: "100%",
                                          direction: Vertical,
                                          panes: [(pane: Pane(Albums), size: "100%", borders: "ALL", border_symbols: Rounded)],
                                      )
                                  ),
                                  (
                                      name: "Playlists",
                                      borders: "ALL",
                                      border_symbols: Rounded,
                                      pane: Split(
                                          size: "100%",
                                          direction: Vertical,
                                          panes: [(pane: Pane(Playlists), size: "100%", borders: "ALL", border_symbols: Rounded)],
                                      )
                                  ),
                                  (
                                      name: "Search",
                                      borders: "ALL",
                                      border_symbols: Rounded,
                                      pane: Split(
                                          size: "100%",
                                          direction: Vertical,
                                          panes: [(pane: Pane(Search), size: "100%", borders: "ALL", border_symbols: Rounded)],
                                      )
                                  ),
                              ],
                          )
                          		'';
    home.file.".config/rmpc/themes/def.ron".text = ''
      #![enable(implicit_some)]
      #![enable(unwrap_newtypes)]
      #![enable(unwrap_variant_newtypes)]
      (
          draw_borders: false,
          show_song_table_header: true,
          background_color: None, 
          default_album_art_path: None,
          header_background_color: None,
          modal_background_color: None,
          modal_backdrop: true,
          format_tag_separator: " | ",
          multiple_tag_resolution_strategy: Last,
          text_color: "#e0def4", 
          preview_label_style: (fg: "#f6c177"),
          preview_metadata_group_style: (fg: "#f6c177", modifiers: "Bold"),
          level_styles: (
              info: (fg: "#c4a7e7", bg: None),
              warn: (fg: "#f6c177", bg: None),
              error: (fg: "#eb6f92", bg: None),
              debug: (fg: "#3e8fb0", bg: None),
              trace: (fg: "#ea9a97", bg: None),
          ),
          cava: (
              bar_width: 2,
              bar_spacing: 1,
              orientation: Bottom,
              bar_color: Gradient({
                    0: "#eb6f92",
                   25: "#ea9a97",
                   50: "#c4a7e7",
                   75: "#9ccfd8",
                  100: "#3e8fb0",
              }),
          ),
          lyrics: (
              timestamp: false,
          ),
          components: {
              "state": Pane(Property(
                  content: [
                      (kind: Text("["), style: (fg: "#f6c177", modifiers: "Bold")),
                      (kind: Property(Status(StateV2())), style: (fg: "#f6c177", modifiers: "Bold")),
                      (kind: Text("] "), style: (fg: "#f6c177", modifiers: "Bold")),
                  ], align: Left,
              )),
              "title": Pane(Property(
                  content: [
                      (kind: Property(Song(Title)), style: (modifiers: "Bold"),
                          default: (kind: Text("No Song"), style: (modifiers: "Bold"))),
                  ], align: Center, scroll_speed: 1
              )),
							"volume": Split(
									direction: Horizontal,
                  panes: [
                      (size: "100%", pane: Pane(Property(content: [(kind: Property(Widget(Volume)), style: (fg: "#c4a7e7"))], align: Right))),
                  ]
              ),
              "elapsed_and_bitrate": Pane(Property(
                  content: [
                      (kind: Property(Status(Elapsed))), 
                      (kind: Text(" / ")), 
                      (kind: Property(Status(Duration))), 
                      (kind: Group([
                          (kind: Text(" (")), 
                          (kind: Property(Status(Bitrate))), 
                          (kind: Text(" kbps)")),
                      ])),
                  ],
                  align: Left,
              )),
              "artist_album": Pane(Property(
                  content: [
                      (kind: Property(Song(Artist)), style: (fg: "#f6c177", modifiers: "Bold"),
                          default: (kind: Text("Unknown"), style: (fg: "#f6c177", modifiers: "Bold"))),
                      (kind: Text(" - ")),
                      (kind: Property(Song(Album)), default: (kind: Text("Unknown Album")))
                  ], align: Center, scroll_speed: 2
              )),
              "states": Pane(Property(
                  content: [
                      (kind: Property(Status(RepeatV2(
                          on_label: " ",
                          off_label: " ",
                          on_style: (fg: "#f6c177", modifiers: "Bold"),
                          off_style: (fg: "#6e6a86", modifiers: "Dim"),
                      )))),
                      (kind: Property(Status(RandomV2(
                          on_label: " ",
                          off_label: " ",
                          on_style: (fg: "#f6c177", modifiers: "Bold"),
                          off_style: (fg: "#6e6a86", modifiers: "Dim"),
                      )))),
                      (kind: Property(Status(SingleV2(
                          on_label: "󰑘 ",
                          off_label: "󰑘 ",
                          oneshot_label: "󰑘 ",
                          on_style: (fg: "#f6c177", modifiers: "Bold"),
                          off_style: (fg: "#6e6a86", modifiers: "Dim"),
                          oneshot_style: (fg: "#eb6f92", modifiers: "Bold"),
                      )))),
                      (kind: Property(Status(ConsumeV2(
                          on_label: " ",
                          off_label: " ",
                          oneshot_label: " ",
                          on_style: (fg: "#f6c177", modifiers: "Bold"),
                          off_style: (fg: "#6e6a86", modifiers: "Dim"),
                          oneshot_style: (fg: "#eb6f92", modifiers: "Dim"),
                      )))),
                      (kind: Text(" / "), style: (fg: "#c4a7e7")), 
                      (kind: Property(Status(QueueTimeRemaining(separator: " "))), style: (fg: "#c4a7e7", modifiers: "Bold")),
                  ], align: Right
              )),
              "top_row": Split(
                  direction: Horizontal,
                  panes: [
                      (size: "23", pane: Component("state")),
                      (size: "100%", borders: "LEFT | RIGHT", pane: Component("title")),
                      (size: "23", pane: Component("volume")),
                  ],
              ),
              "bottom_row": Split(
                  direction: Horizontal,
                  panes: [
                      (
                          size: "23",
                          pane: Component("elapsed_and_bitrate"),
                      ),
                      (
                          size: "100%",
                          borders: "LEFT | RIGHT",
                          pane: Component("artist_album"),
                      ),
                      (
                          size: "23",
                          pane: Component("states"),
                      ),
                  ],
              ),
              "header": Split(
                  direction: Vertical,
                  panes: [
                      (
                          size: "1",
                          direction: Vertical,
                          pane: Component("top_row"),
                      ),
                      (
                          size: "1",
                          direction: Vertical,
                          pane: Component("bottom_row"),
                      ),
                  ] 
              ),
              "progress_bar": Split(
                  direction: Horizontal,
                  panes: [
                      (
                          pane: Pane(Property(content: [(kind: Property(Status(StateV2(playing_label: "  ", paused_label: "  ", stopped_label: "  ",
                              playing_style: (fg: "#c4a7e7"), paused_style: (fg: "#3e8fb0"), stopped_style: (fg: "#eb6f92")
                          ))))], align: Left)),
                          size: "3",
                      ),
                      (
                          size: "100%",
                          pane: Pane(ProgressBar),
                      ),
                      (
                          size: "13",
                          pane: Pane(Property(
                              content: [
                                  (kind: Property(Status(Elapsed))),
                                  (kind: Text(" / ")),
                                  (kind: Property(Status(Duration))),
                              ], align: Right,
                          )),
                      ),
                  ]
              ),
          },
          layout: Split(
              direction: Vertical,
              panes: [
                  (
                      size: "4",
                      borders: "ALL",
                      pane: Component("header"),
                  ),
                  (
                      size: "3",
                      borders: "ALL",
                      pane: Pane(Tabs),
                  ),
                  (
                      size: "100%",
                      borders: "ALL",
                      pane: Pane(TabContent), 
                  ),
                  (
                      size: "3",
                      borders: "ALL",
                      pane: Component("progress_bar"),
                  ),
              ]
          ),
          symbols: (
              song: "🎵",
              dir: "📁",
              playlist: "🎼",
              marker: "\u{e0b0}",
              ellipsis: "…",
              song_style: None,
              dir_style: None,
          ),
          progress_bar: (
              symbols: ["", "█", "", "█", "" ],
              track_style: (fg: "#393552"),
              elapsed_style: (fg: "#c4a7e7"),
              thumb_style: (fg: "#c4a7e7", bg: "#393552"),
          ),
          scrollbar: (
              symbols: ["│", "█", "▲", "▼"],
              track_style: (),
              ends_style: (),
              thumb_style: (fg: "#c4a7e7"),
          ),
          browser_column_widths: [20, 38, 42],
          browser_song_format: [
              (
                  kind: Group([
                      (kind: Property(Track)),
                      (kind: Text(" - ")),
                  ]),
              ),
              (
                  kind: Property(Other("name")),
                  default: (
                      kind: Group([
                          (kind: Property(Artist)),
                          (kind: Text(" - ")),
                          (kind: Property(Title)),
                      ]),
                      default: (kind: Property(Filename))
                  ),
              ),
              (
                  kind: Text(" Rating: "),
              ),
              (
                  kind: Sticker("rating"),
                  default: (kind: Text("-"))
              ),
          ],
          tab_bar: (
              active_style: (fg: "#232136", bg: "#c4a7e7", modifiers: "Bold"),
              inactive_style: (),
          ),
          highlighted_item_style: (fg: "#c4a7e7", modifiers: "Bold"),
          current_item_style: (fg: "#232136", bg: "#c4a7e7", modifiers: "Bold"),
          borders_style: (fg: "#6e6a86"),
          highlight_border_style: (fg: "#ea9a97"),
          song_table_album_separator: None,
          song_table_format: [
              (
                  prop: (kind: Property(Position)),
                  width: "2",
                  alignment: Right,
                  label: ""
              ),
              (
                  prop: (kind: Property(Other("albumartist")), default: (kind: Property(Artist), default: (kind: Text("Unknown")))),
                  width: "20%",
                  label: "Artist"
              ),
              (
                  prop: (kind: Property(Title), default: (kind: Text("Unknown"))),
                  width: "35%",
              ),
              (
                  prop: (kind: Property(Album), default: (kind: Text("Unknown Album"))),
                  width: "45%",
              ),
              (
                  prop: (kind: Property(Duration),default: (kind: Text("-"))),
                  width: "5",
                  alignment: Right,
                  label: "Len"
              ),
          ],
          header: (rows: []),
      )
    '';
  };
}
