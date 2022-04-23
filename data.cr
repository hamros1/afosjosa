D_LEFT = 0
D_RIGHT = 1
D_UP = 2
D_DOWN = 3

NO_ORIENTATION = 0
HORIZ = 1
VERT = 2

BS_NORMAL = 0
BS_NONE = 1
BS_PIXEL = 2

DONT_KILL_WINDOW = 0
KILL_WINDOW = 1
KILL_CLIENT = 2

ADJ_NONE = 0
ADJ_LEFT_SCREEN_EDGE = (1 << 0)
ADJ_RIGHT_SCREEN_EDGE = (1 << 1)
ADJ_UPPER_SCREEN_EDGE = (1 <<2)
ADJ_LOWER_SCREEN_EDGE = (1 << 4)

OFF = 0
ON = 1
NO_GAPS = 2

HEBM_NONE = ADJ_NONE
HEBM_VERTICAL = ADJ_LEFT_SCREEN_EDGE | ADJ_RIGHT_SCREN_EDGE
HEBM_HORIZONTAL = ADJ_UPPER_SCREEN_EDGE | ADJ_LOWER_SCREEN_EDGE
HEBM_BOTH = HEBM_VERTICAL | HEBM_HORIZONTAL
HEBM_SMART = (1 << 5)
HEBM_SMART_NO_GAPS = (1 << 6)

MM_REPLACE = 0
MM_ADD = 1

L_DEFAULT = 0
L_STACKED = 1
L_TABBED = 2
L_DOCKAREA = 3
L_OUTPUT = 4
L_SPLITV = 5
L_SPLITH = 6

B_KEYBOARD = 0
B_MOUSE = -1

I3_XKB_GROUP_MASK_ANY = 0
I3_XKB_GROUP_MASK_1 = (1 << 0)
I3_XKB_GROUP_MASK_2 = (1 << 1)
I3_XKB_GROUP_MASK_3 = (1 << 2)
I3_XB_GROUP_MASK_4 = (1 << 3)

POINTER_WARPING_OUTPUT = 0
POINTER_WARPING_NONE = 1

struct Margin
	property top : Int32
	property left : Int32
	property bottom : Int32
	property right : Int32
end

struct Gaps
	property inner : Int32
	property outer : Margin
end

FOCUS_WRAPPING_OFF = 0
FOCUS_WRAPPING_ON = 1
FOCUS_WRAPPING_FORCE = 2

struct Rect
	property x : UInt32
	property y : UInt32
	property width : UInt32
	property height : UInt32
end

struct ReservedPixels
	property left : UInt32
	property right : UInt32
	property top : UInt32
	property bottom : UInt32
end

struct Dimensions
	property width : UInt32
	property height : UInt32
end

struct DecoRenderParams
	property border_style : Int32
	property con_rect : Dimensions
	property con_window_rect : Dimensions
	property con_deco_rect : Rect
	property background : Color
	property parent_layout : Layout
	property con_is_leaf : Bool
end

struct WorkspaceAssignment
	property name : String
	property output : String
	property gaps : Gaps
	property ws_assignments : Dequeue(WorkspaceAssignment)
end

struct IgnoreEvent
	property sequence : Int32
	property response_type : Int32
	property added : Time
	property ignore_events : Dequeue(IgnoreEvent)
end

struct StartupSequence
	property id : String
	property workspace : String
	property context : SnLauncherContext
	property deleted_at : Time
	property sequences : Dequeue(StartupSequence)
end

struct BindingKeycode
	property keycode : XcbKeycode
	property modifiers : I3EventStateMask
	property keycodes : Dequeue(BindingKeycode)
end

struct Binding
	property input_type : InputType
	property border : Bool
	property whole_window : Bool
	property exclude_titlebar : Bool
	property keycode : UInt32
	property event_state_mask : EventStateMask
	property symbol : String
	property keycodes : Dequeue(BindingKeycode)
	property command : String
	property bindings : Dequeue(Binding)
end

struct Autostart
	property command : String
	property no_startup_id : Bool
	property autostarts : Dequeue(Autostart)
	property autostarts_always : Dequeue(Autostart)
end

struct OutputName
	property name : String
	property names : Dequeue(OutputName)
end

struct XcbOutput
	property id : XcbRandrOutput
	property active : Bool
	property changed : Bool
	property to_be_disabled : Bool
	property primary : Bool
	property names : Dequeue(OutputName)
	property con : Con
	property rect : Rect
	property outputs : Dequeue(XcbOutput)
end

struct Window
	property id : Window
	property leader : XcbWindow
	property transient_for : XcbWindow
	property nr_assignments : UInt32
	property ran_assignments : Array(Assignment)
	property class_class : String
	property class_instance : String
	property name : String
	property role : String
	property name_x_changed : Bool
	property uses_net_wm_name : Bool
	property needs_take_focus : Bool
	property doesnt_accept_focus : Bool
	property window_type : XcbAtom
	property wm_desktop : UInt32
	property reserved : ReservedPixels
	property depth : UInt16
	property base_width : Int32
	property base_height : Int32
	property width_increment : Int32
	property height_increment : Int32
	property min_width : Int32
	property min_height : Int32
	property aspect_ratio : Float64
end

struct Match
	property error : String
	property title : Regex
	property application : Regex
	property class_ : Regex
	property instance : Regex
	property mark : Regex
	property window_role : Regex
	property workspace : Regex
	property window_type : XcbAtom
	property id : XcbWindow
	property con_id : Con
	property matches : Dequeue(Match)
	property restart_mode : Bool
end

struct AssignmentDest
	property command : String
	property workpace : String
	property output : String
end

struct Assignment
	property match : Match
	property dest : AssignmentDest
	property assignments : Dequeue
end

struct Mark
	property name : String
	property marks : Mark
end

struct Con
	property mapped : Bool
	property urgent : Bool
	property ignore_unmap : UInt8
	property frame : Surface
	property frame_buffer : Surface
	property pixmap_recreated : Bool
	property num : Int32
	property gaps : Gaps
	property parent : Con
	property rect : Rect
	property window_rect : Rect
	property deco_rect : Rect
	property geometry : Rect
	property name : String
	property title_format : String
	property stick_group : String
	property marks : Dequeue(Mark)
	property mark_changed : Bool
	property percent : Float64
	property border_width : Int32
	property current_border_width : Int32
	property window : Window
	property urgency_timer : EvTimer
	property deco_render_params : DecoRenderParams
	property swallow : Dequeue(Match)
	property fullscreen_mode : FullscreenMode
	property sticky : Bool
	property layout : Layout
	property last_split_layout : Layout
	property workspace_layout : Layout
	property border_style : BorderStyle
	property nodes : Dequeue(Con)
	property focused : Dequeue(Con)
	property all_cons : Dequeue(Con)
	property floating : Dequeue(Con)
	property old_id : Int32
	property depth : UInt16
	property colormap : XcbColormap
end
