import qualified Data.Map                         as M
import           Data.Monoid                      (All, Endo)
import           Data.Ratio                       ((%))
import           System.Exit
import           XMonad
import           XMonad.Util.SpawnOnce            (spawnOnce)

import           XMonad.Layout.ResizableTile      (ResizableTall(..),
                                                   MirrorResize(MirrorExpand,
                                                                MirrorShrink)
                                                  )
import           XMonad.Layout.Mosaic             (Aspect (Reset), mosaic)
import           XMonad.Layout.NoBorders          (noBorders)

import           XMonad.Actions.CopyWindow        (copy, copyToAll, kill1,
                                                   killAllOtherCopies,
                                                   wsContainingCopies)
import           XMonad.Actions.CycleWS           (toggleWS')
import           XMonad.Actions.DynamicWorkspaces (addHiddenWorkspace,
                                                   removeEmptyWorkspaceAfterExcept,
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

-- ------------------------------------------------------------
--
-- predefined workspaces
--
-- ------------------------------------------------------------
-- default workspaces they will always be there.
-- And they are protected against renaming
myWorkspaces :: [String]
myWorkspaces = ["1", "2", "3", "4"]

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
    , removeEmptyWorkspaceAfterExcept myWorkspaces $ windows $ f i)
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

-- todo : make this function readable
toggleFloating :: W.RationalRect -> Window -> X()
toggleFloating position w =
  do floating <- isFloat w
     call floating w
  where
    call floating =
      if (floating)
      then
        windows . W.sink
      else
        windows . (\ord -> W.float ord position)


myAdditionaKeys :: [(String, X ())]
myAdditionaKeys
    -- ------------------------------------------------------------
    --
    -- dynamic workspaces
    --
    -- ------------------------------------------------------------
    -- switch to workspace
 =
  [ ( "M4-`"
    , removeEmptyWorkspaceAfterExcept myWorkspaces $
      withWorkspace autoXPConfig (windows . W.greedyView))
    -- move focused window to workspace
  , ("M4-S-<Space>", withWorkspace myXPConfig (windows . W.shift))
    -- copy focused window to workspace
  , ("M4-C-<Space>", withWorkspace myXPConfig (windows . copy))
    -- make windows "sticky" by copy and remove them to and from all other windows
  , ( "M4-s"
    , do copies <- wsContainingCopies
         if not (null copies)
           then killAllOtherCopies
           else windows copyToAll
    )
    -- rename workspace but make sure myWorkspaces still exist
  , ( "M4-r"
    , do renameWorkspace myXPConfig
         sequence_ [addHiddenWorkspace ws | ws <- myWorkspaces])
  , ("M4-<Esc>", toggleWS' ["NSP"])
  ] ++
    -- ------------------------------------------------------------
    --
    -- launch applications
    --
    -- ------------------------------------------------------------
    -- launch a terminal
  [ ("M4-<Return>", spawn $ XMonad.terminal defaults)
    -- launch dmenu
  , ("M4-<Space>", spawn "~/.dmenu/dmenu_run")
    -- close focused window
    -- kills only a copy (not the window)
  , ("M4-q", kill1)
    -- create screenshot
  , ( "<Print>"
    , spawn "maim --select --format=png /dev/shm/$(date +%F-%H%M%S).png")
    -- invert color for bright or dark days
  , ("<Pause>", spawn "xcalib -invert -alter")
    -- open scratchpad
  , ("M4--", scratchpadSpawnAction defaults)
  ] ++
    -- ------------------------------------------------------------
    --
    -- Window and Layout
    --
    -- ------------------------------------------------------------
    -- Move focus to the next window
  [ ("M4-j", windows W.focusDown)
    -- Move focus to the previous window
  , ("M4-k", windows W.focusUp)
    -- Move focus to the master window
  , ("M4-m", windows W.focusMaster)
    -- Swap the focused window and the master window
  , ("M4-<Tab>", windows W.swapMaster)
    -- Swap the focused window with the next window
  , ("M4-S-j", windows W.swapDown)
    -- Swap the focused window with the previous window
  , ("M4-S-k", windows W.swapUp)
    -- Rotate through the available layout algorithms
  , ("M4-f", sendMessage NextLayout)
    -- Shrink the current area
  , ( "M4-h"
    , do sendMessage MirrorShrink
         sendMessage Reset)
    -- Shrink the master area
  , ( "M4-S-h"
    , do sendMessage Shrink
         sendMessage Reset)
    -- Expand the current area
  , ( "M4-l"
    , do sendMessage MirrorExpand
         sendMessage Reset)
    -- Expand the master area
  , ( "M4-S-l"
    , do sendMessage Expand
         sendMessage Reset)
    -- Toggle window tiling/floating
  , ("M4-t", withFocused $ toggleFloating (W.RationalRect 0.65 0.65 0.35 0.35))
    -- Increment the number of windows in the master area
  , ("M4-,", sendMessage (IncMasterN 1))
    -- Deincrement the number of windows in the master area
  , ("M4-.", sendMessage (IncMasterN (-1)))
  ] ++
    -- ------------------------------------------------------------
    --
    -- Xmonad Commands
    --
    -- ------------------------------------------------------------
    --  Quit xmonad
  [ ("M4-S-q", io exitSuccess)
    --  restart xmonad
  , ("M4-S-r", spawn "xmonad --recompile; xmonad --restart")
    --  select next screen/monitor
  , ("M4-<Backspace>", selectNextScreen)
    --  move window next screen/monitor
    -- , ("M4-S-<Backspace>", moveWindowToNextScreen)
  ] ++
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
--
-- Layouts
--
------------------------------------------------------------------------
myLayout = resizeableTall ||| noBorders Full
  where
     -- ResizableTall is same as Tall but has resizable rightside window
     resizeableTall = ResizableTall nmaster delta ratio []

     -- The default number of windows in the master pane
     nmaster = 1

     -- Default proportion of screen occupied by master pane
     ratio   = 1/2

     -- Percent of screen to increment by when resizing panes
     delta   = 3/100

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
    , resource =? "desktop_window" --> doIgnore
    , resource =? "kdesktop" --> doIgnore
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
startUp = do
  spawnOnce "xsetroot -cursor_name left_ptr"
  -- set background
  spawnOnce "feh --randomize --bg-tile ~/.wallpapers/*"
  -- java fix
  setWMName "LG3D"

-- ------------------------------------------------------------
--
-- xmobar
--
-- ------------------------------------------------------------
myXmobarPP :: PP
myXmobarPP =
  xmobarPP
  { ppCurrent = xmobarColor solarizedDefaultCyan "" . wrap "[" "]"
  , ppUrgent = xmobarColor solarizedDefaultRed "" . wrap "!" ""
  , ppHidden = xmobarColor solarizedDarkBase0 "" . wrap "" ""
  , ppWsSep = " | "
  , ppTitle = xmobarColor solarizedDefaultCyan "" . shorten 100
  }

toggleStrutsKey :: XConfig t -> (KeyMask, KeySym)
toggleStrutsKey XConfig {XMonad.modMask = modm} = (modm, xK_equal)

------------------------------------------------------------------------
-- Now run xmonad with all the defaults we set up.
-- Run xmonad with the settings you specify. No need to modify this.
--
main :: IO ()
main = xmonad =<< statusBar "xmobar" myXmobarPP toggleStrutsKey defaults

-- A structure containing your configuration settings, overriding
-- fields in the default config. Any you don't override, will
-- use the defaults defined in xmonad/XMonad/Config.hs
--
-- No need to modify this.
--
defaults =
  def
  { terminal = "urxvt"
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
  , workspaces = myWorkspaces
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
  } `additionalKeysP`
  myAdditionaKeys

autoXPConfig :: XPConfig
autoXPConfig = myXPConfig {autoComplete = Just 5000}

myXPConfig :: XPConfig
myXPConfig =
  def
  { bgColor = solarizedDarkBase03
  , fgColor = solarizedDarkBase0
  , promptBorderWidth = 0
  , font = "xft:inconsolata:pixelsize=18:antialias=true:hinting=true"
  }

solarizedDarkBase0 :: String
solarizedDarkBase0 = "#839496"

solarizedDarkBase00 :: String
solarizedDarkBase00 = "#657b83"

solarizedDarkBase01 :: String
solarizedDarkBase01 = "#586e75"

solarizedDarkBase02 :: String
solarizedDarkBase02 = "#073642"

solarizedDarkBase03 :: String
solarizedDarkBase03 = "#002b36"

solarizedDarkBase1 :: String
solarizedDarkBase1 = "#93a1a1"

solarizedDarkBase2 :: String
solarizedDarkBase2 = "#eee8d5"

solarizedDarkBase3 :: String
solarizedDarkBase3 = "#fdf6e3"

solarizedDefaultBlue :: String
solarizedDefaultBlue = "#268bd2"

solarizedDefaultCyan :: String
solarizedDefaultCyan = "#2aa198"

solarizedDefaultGreen :: String
solarizedDefaultGreen = "#859900"

solarizedDefaultMagenta :: String
solarizedDefaultMagenta = "#d33682"

solarizedDefaultOrange :: String
solarizedDefaultOrange = "#cb4b16"

solarizedDefaultRed :: String
solarizedDefaultRed = "#dc322f"

solarizedDefaultViolet :: String
solarizedDefaultViolet = "#6c71c4"

solarizedDefaultYellow :: String
solarizedDefaultYellow = "#b58900"

solarizedLightBase0 :: String
solarizedLightBase0 = "#657b83"

solarizedLightBase00 :: String
solarizedLightBase00 = "#839496"

solarizedLightBase01 :: String
solarizedLightBase01 = "#93a1a1"

solarizedLightBase02 :: String
solarizedLightBase02 = "#eee8d5"

solarizedLightBase03 :: String
solarizedLightBase03 = "#fdf6e3"

solarizedLightBase1 :: String
solarizedLightBase1 = "#586e75"

solarizedLightBase2 :: String
solarizedLightBase2 = "#073642"

solarizedLightBase3 :: String
solarizedLightBase3 = "#002b36"
