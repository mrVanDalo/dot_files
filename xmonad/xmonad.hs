import qualified Data.Map                         as M
import           Data.Monoid                      (All, Endo)
import           Data.Ratio                       ((%))
import           FloatKeys                        (keysResizeWindow)
import           System.Exit
import           XMonad
import           XMonad.Layout.Mosaic             (Aspect (Reset), mosaic)
import           XMonad.Layout.NoBorders          (smartBorders, noBorders)
import           XMonad.Layout.ResizableTile      (MirrorResize (MirrorExpand, MirrorShrink),
                                                   ResizableTall (..))
import           XMonad.Util.SpawnOnce            (spawnOnce)

import           XMonad.Actions.CopyWindow        (copy, copyToAll, kill1,
                                                   killAllOtherCopies,
                                                   wsContainingCopies)
import           XMonad.Actions.CycleWS           (toggleWS')
import           XMonad.Actions.DynamicWorkspaces (addHiddenWorkspace, removeEmptyWorkspaceAfterExcept,
                                                   renameWorkspace,
                                                   withWorkspace)
import           XMonad.Actions.UpdatePointer     (updatePointer)
import           XMonad.Actions.Warp              (warpToScreen)
import           XMonad.Hooks.DynamicLog          (PP (..), dynamicLog, shorten,
                                                   statusBar, wrap, xmobarColor,
                                                   xmobarPP)
import           XMonad.Hooks.SetWMName           (setWMName)
import           XMonad.Prompt                    (XPConfig (..))
import qualified XMonad.StackSet                  as W
import           XMonad.Util.EZConfig             (additionalKeysP)
import           XMonad.Util.Scratchpad           (scratchpadManageHook,
                                                   scratchpadSpawnAction)
import           XMonad.Hooks.UrgencyHook         (SpawnUrgencyHook(..),
                                                   withUrgencyHook,
                                                   BorderUrgencyHook(..))
import           XMonad.Util.Types                (Direction2D(U,D,L,R))
import qualified Solarized


import           XMonad.Layout.AutoMaster         (autoMaster)
import           XMonad.Layout.Magnifier          (magnifiercz', magnifier') -- overlays the focused window a bit which is nice (except the master window)


------------------------------------------------------------------------
--
-- Layouts
--
------------------------------------------------------------------------

-- ResizableTall is same as Tall but has resizable rightside window
myLayout = smartBorders (magnifier' (autoMaster 1 (1 / 100 ) resizeableTall)) ||| noBorders Full
  where
    resizeableTall = ResizableTall nmaster delta ratio []
     -- The default number of windows in the master pane
    nmaster = 1
     -- Default proportion of screen occupied by master pane
    ratio = 1 / 2
     -- Percent of screen to increment by when resizing panes
    delta = 3 / 100

--- todo :

-- ------------------------------------------------------------
--
-- predefined workspaces
--
-- ------------------------------------------------------------
-- default workspaces they will always be there.
-- And they are protected against renaming
myWorkspaces :: [String]
myWorkspaces = ["1", "2", "3", "4"]

-- workspaces names to be used only by one program, partly spawning on startup.
autoSpawnWorkspaces = [ "-copyq" ]

-- theses workspaces should not be removed by the workspace
-- switch commands
nonRemovableWorkspaces = myWorkspaces ++ autoSpawnWorkspaces

-- ------------------------------------------------------------
--
-- key definitions
--
-- ------------------------------------------------------------
myKeys :: XConfig Layout -> M.Map (ButtonMask, KeySym) (X ())
myKeys XConfig {modMask = modm} =
  M.fromList $
    -- ------------------------------------------------------------
    --
    -- predefined workspaces
    --
    -- ------------------------------------------------------------
    --
    -- mod-[1..9], Switch to workspace N
  [ ( (m .|. modm, k)
    , removeEmptyWorkspaceAfterExcept nonRemovableWorkspaces $ windows $ f i)
  | (i, k) <- zip myWorkspaces [xK_1 .. xK_9]
  , (f, m) <- [(W.greedyView, 0)]
  ] ++
    -- mod-<shift>-[1..9] move window to workspace N
    -- mod-<control>-[1..9] copy window to workspace N
  [ ((m .|. modm, k), windows $ f i)
  | (i, k) <- zip myWorkspaces [xK_1 .. xK_9]
  , (f, m) <- [(W.shift, shiftMask), (copy, controlMask)]
  ]

-- ------------------------------------------------------------
--
-- select next Screen/Monitor.
--  (works for 2 and 1 monitor, but might also work for more)
--
-- ------------------------------------------------------------
selectNextScreen :: X ()
selectNextScreen = do
  W.StackSet {W.current = current, W.visible = visible} <- gets windowset
  warpToScreen (nextScreen current visible) (1 % 2) (1 % 2)
  where
    nextScreen current [] = W.screen current
    nextScreen _ (x:_)    = W.screen x

isFloat :: Window -> X Bool
isFloat w = gets windowset >>= \ws -> return (M.member w $ W.floating ws)

-- | add different shortcuts for different type
-- of situation. Floating or Tiling
floatTileCommand :: X () -> X () -> Window -> X ()
floatTileCommand forFloating forTileing window = do
  floating <- isFloat window
  if floating
    then forFloating
    else forTileing

toggleFloating :: W.RationalRect -> Window -> X ()
toggleFloating position =
  floatTileCommand
    (withFocused (windows . W.sink))
    (withFocused (windows . (`W.float` position)))

multiKeys [] = []
multiKeys ((key, command):xs) = (createMultiKey key command) ++ multiKeys xs
  where
    createMultiKey keyString command =
      [("M4-" ++ keyString, command), ("M4-z " ++ keyString, command)]

myAdditionaKeys :: [(String, X ())]
myAdditionaKeys
    -- ------------------------------------------------------------
    --
    -- dynamic workspaces
    --
    -- ------------------------------------------------------------
    -- switch to workspace
 =
  (multiKeys
     [ ( "`"
       , removeEmptyWorkspaceAfterExcept nonRemovableWorkspaces $
         withWorkspace autoXPConfig (windows . W.greedyView))
    -- move focused window to workspace
     , ("S-<Space>", withWorkspace myXPConfig (windows . W.shift))
    -- copy focused window to workspace
     , ("C-<Space>", withWorkspace myXPConfig (windows . copy))
    -- make windows "sticky" by copy and remove them to and from all other windows
     , ( "s"
       , do copies <- wsContainingCopies
            if not (null copies)
              then killAllOtherCopies
              else windows copyToAll)
    -- rename workspace but make sure myWorkspaces still exist
     , ( "r"
       , do renameWorkspace myXPConfig
            sequence_ [addHiddenWorkspace ws | ws <- myWorkspaces])
     , ("<Esc>", toggleWS' ["NSP"])
     ]) ++
    -- ------------------------------------------------------------
    --
    -- launch applications
    --
    -- ------------------------------------------------------------
  (multiKeys
    -- launch a terminal
     [ ("<Return>", spawn $ XMonad.terminal defaults)
    -- launch dmenu
     , ("<Space>", spawn "~/.dmenu/dmenu_run")
    -- close focused window
    -- kills only a copy (not the window)
     , ("q", kill1)
    -- create screenshot
    -- open scratchpad
     , ("-", scratchpadSpawnAction defaults)
     ]) ++
  [ ( "<Print>"
    , spawn "maim --select --format=png /dev/shm/$(date +%F-%H%M%S).png")
    -- invert color for bright or dark days
  , ("<Pause>", spawn "xcalib -invert -alter")
  ] ++
    -- ------------------------------------------------------------
  --
    -- Window and Layout
    --
    -- ------------------------------------------------------------
  (multiKeys
    -- Move focus to the next window
     [ ("j", windows W.focusDown)
    -- Move focus to the previous window
     , ("k", windows W.focusUp)
    -- Move focus to the master window
     , ("m", windows W.focusMaster)
    -- Swap the focused window and the master window
     , ("<Tab>", windows W.swapMaster)
    -- Swap the focused window with the next window
     , ("S-j", windows W.swapDown)
    -- Swap the focused window with the previous window
     , ("S-k", windows W.swapUp)
    -- Rotate through the available layout algorithms
     , ("f", sendMessage NextLayout)
    -- Shrink the current area
    -- Shrink the master area
     , ( "h"
       , withFocused $
         floatTileCommand
           (withFocused (keysResizeWindow (10, 0) (1, 1 % 2)))
           (do sendMessage Shrink
               sendMessage Reset))
    -- Expand the master area
     , ( "l"
       , withFocused $
         floatTileCommand
           (withFocused (keysResizeWindow (-10, 0) (1, 1 % 2)))
           (do sendMessage Expand
               sendMessage Reset))
    -- Expand the current area
     , ( "S-l"
       , withFocused $
         floatTileCommand
           (withFocused (keysResizeWindow (0, -10) (1 % 2, 1)))
           (do sendMessage MirrorExpand
               sendMessage Reset))
     , ( "S-h"
       , withFocused $
         floatTileCommand
           (withFocused (keysResizeWindow (0, 10) (1 % 2, 1)))
           (do sendMessage MirrorShrink
               sendMessage Reset))
    -- Toggle window tiling/floating
     , ("t", withFocused $ toggleFloating (W.RationalRect 0.65 0.65 0.35 0.35))
    -- Increment the number of windows in the master area
     , (",", sendMessage (IncMasterN 1))
    -- Deincrement the number of windows in the master area
     , (".", sendMessage (IncMasterN (-1)))
     ]) ++
    -- ------------------------------------------------------------
    --
    -- Xmonad Commands
    --
    -- ------------------------------------------------------------
    --  Quit xmonad
  (multiKeys
     [ ("S-q", io exitSuccess)
    --  restart xmonad
     , ("S-r", spawn "xmonad --recompile; xmonad --restart")
    --  select next screen/monitor
     , ("<Backspace>", selectNextScreen)
    --  move window next screen/monitor
    -- , ("M4-S-<Backspace>", moveWindowToNextScreen)
     ]) ++
    -- ------------------------------------------------------------
    --
    -- Volume Control
    --
    -- ------------------------------------------------------------
  [ ("<XF86AudioRaiseVolume>", spawn "amixer set Master 5%+")
  , ("<XF86AudioLowerVolume>", spawn "amixer set Master 5%-")
  , ("<XF86AudioMute>", spawn "amixer set Master toggle")
  ]

------------------------------------------------------------------------
-- Mouse bindings: default actions bound to mouse events
--
mouse :: XConfig t -> M.Map (KeyMask, Button) (Window -> X ())
-- mouse _ = M.empty
mouse XConfig {XMonad.modMask = modm} =
  M.fromList
    -- mod-button1, Set the window to floating mode and move by dragging
    [ ( (modm, button1)
      , \w -> do
          focus w
          mouseMoveWindow w
          windows W.shiftMaster)
    -- mod-button2, Raise the window to the top of the stack
    , ( (modm, button2)
      , \w -> do
          focus w
          windows W.shiftMaster)
    -- mod-button3, Set the window to floating mode and resize by dragging
    , ( (modm, button3)
      , \w -> do
          focus w
          mouseResizeWindow w
          windows W.shiftMaster)
    -- you may also bind events to the mouse scroll wheel (button4 and button5)
    ]



------------------------------------------------------------------------
-- Window rules:
-- Execute arbitrary actions and WindowSet manipulations when managing
-- a new window. You can use this to, for example, always float a
-- particular program, or have a client always appear on a particular
-- workspace.
--
-- To find the property name associated with a program, use
-- > xprop | grep WM_CLASS
-- and click on the client you're interested in.
--
-- To match on the WM_NAME, you can use 'title' in the same way that
-- 'className' and 'resource' are used below.
--
myManageHook :: Query (Endo WindowSet)
myManageHook =
  composeAll
    [ className =? "Gimp" --> doFloat
    , resource =? "copyq" --> doShift "-copyq"
    , scratchpadManageHook
        (W.RationalRect
          -- | percentage distance from left
           0.2
          -- | percentage distance from top
           0.2
          -- | width
           0.6
          -- | height
           0.6)
    ]

------------------------------------------------------------------------
-- Event handling
-- * EwmhDesktops users should change this to ewmhDesktopsEventHook
--
-- Defines a custom handler function for X Events. The function should
-- return (All True) if the default handler is to be run afterwards. To
-- combine event hooks use mappend or mconcat from Data.Monoid.
--
myEventHook :: Event -> X All
myEventHook = mempty

------------------------------------------------------------------------
-- Status bars and logging
-- Perform an arbitrary action on each internal state change or X event.
-- See the 'XMonad.Hooks.DynamicLog' extension for examples.
--
myLogHook :: X ()
myLogHook = do
  dynamicLog
    -- make sure the pointer always follows the focused window, when we use shortcuts
  updatePointer (0.5, 0.5) (0, 0)

------------------------------------------------------------------------
-- Startup hook
-- Perform an arbitrary action each time xmonad starts or is restarted
-- with mod-q.  Used by, e.g., XMonad.Layout.PerWorkspace to initialize
-- per-workspace layout choices.
--
-- By default, do nothing.
startUp :: X ()
startUp
  -- java fix
 = do
  setWMName "LG3D"
  -- set cursor image
  spawn "xsetroot -cursor_name left_ptr"
  -- set background
  -- todo : this sometimes does not work
  spawn "feh --randomize --bg-tile ~/.wallpapers/*"
  -- start copyq
  spawnOnce "copyq"


------------------------------------------------------------------------
-- Now run xmonad with all the defaults we set up.
-- Run xmonad with the settings you specify. No need to modify this.
--
main :: IO ()
main = do
  xmonad $ withUrgencyHook (SpawnUrgencyHook "echo emit Urgency ") defaults


-- A structure containing your configuration settings, overriding
-- fields in the default config. Any you don't override, will
-- use the defaults defined in xmonad/XMonad/Config.hs
--
-- No need to modify this.
--
defaults =
  def
    { terminal = "xterm"
  -- Whether focus follows the mouse pointer.
    , focusFollowsMouse = True
  -- Whether clicking on a window to focus also passes the click to the window
    , clickJustFocuses = False
    , borderWidth = 1
  -- modMask lets you specify which modkey you want to use.
  -- mod1Mask ("left alt").
  -- mod3Mask ("right alt")
  -- mod4Mask ("windows key")
    , modMask = mod4Mask
    , workspaces = nonRemovableWorkspaces
    , normalBorderColor = "#dddddd"
    , focusedBorderColor = "#ff0000"
  -- key bindings
    , keys = myKeys
    , mouseBindings = mouse
  -- hooks, layouts
    , layoutHook = myLayout
    , manageHook = myManageHook
    , handleEventHook = myEventHook
    , logHook = myLogHook
    , startupHook = startUp
    -- tabbed config
    } `additionalKeysP`
  myAdditionaKeys

autoXPConfig :: XPConfig
autoXPConfig = myXPConfig {autoComplete = Just 5000}

myXPConfig :: XPConfig
myXPConfig =
  def
    { bgColor = Solarized.darkBase03
    , fgColor = Solarized.darkBase0
    , promptBorderWidth = 0
    , font = "xft:inconsolata:pixelsize=18:antialias=true:hinting=true"
    }

