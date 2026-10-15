package
{
	import ssf2mm.shared.EngineRefs;
	import flash.display.Sprite;
	import flash.filters.DropShadowFilter;
	import flash.filters.GlowFilter;
	import flash.geom.Point;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;

	/**
	 * Display helpers: text fields, parenting, coordinate conversion, stage/root lookup.
	 */
	public class ProfileUi
	{
		internal var mod:ControllerProfilesMod;

		public function ProfileUi(owner:ControllerProfilesMod)
		{
			mod = owner;
		}

		private static function log(msg:String):void
		{
			ControllerProfilesMod.log(msg);
		}

		internal static function hitTextField(tf:TextField, stageX:Number, stageY:Number):Boolean
		{
			if (!tf)
			{
				return (false);
			};
			try
			{
				return (tf.hitTestPoint(stageX, stageY, true));
			}
			catch (err:*)
			{
			};
			return (false);
		}

		internal static function hitSprite(sp:Sprite, stageX:Number, stageY:Number):Boolean
		{
			if (!sp)
			{
				return (false);
			};
			try
			{
				return (sp.hitTestPoint(stageX, stageY, true));
			}
			catch (err:*)
			{
			};
			return (false);
		}

		internal static function menuText(label:String, size:int, color:uint):TextField
		{
			var tf:TextField;
			tf = new TextField();
			tf.autoSize = TextFieldAutoSize.LEFT;
			tf.selectable = false;
			tf.mouseEnabled = false;
			tf.defaultTextFormat = new TextFormat("Arial", size, color, true);
			tf.text = label;
			tf.filters = [new GlowFilter(0x000000, 1, 2, 2, 8, 1), new DropShadowFilter(2, 45, 0, 0.8, 2, 2)];
			return (tf);
		}

		internal static function textFormatFrom(src:TextField):TextFormat
		{
			if (!src)
			{
				return (null);
			};
			try
			{
				return (src.defaultTextFormat);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal static function copyFilters(src:TextField, dest:TextField):void
		{
			try
			{
				if (src && src.filters && src.filters.length > 0)
				{
					dest.filters = src.filters;
				};
			}
			catch (err:*)
			{
			};
		}

		internal static function rootAdd(child:Sprite):void
		{
			var root:*;
			root = mainRoot();
			if (root)
			{
				try
				{
					root.addChild(child);
				}
				catch (err:*)
				{
					log("rootAdd failed: " + err);
				};
			}
			else
			{
				log("rootAdd: Main.Root missing");
			};
		}

		/** Parent Controls dropdown to SubMenu (checkbox depth); CSS lists stay on Main.Root. */
		internal function resolveUiParent(anchor:*):*
		{
			var sub:*;
			if (mod.m_controls && mod.m_profileBar && anchor == mod.m_profileBar)
			{
				sub = mod.m_controls["SubMenu"];
				if (sub)
				{
					return (sub);
				};
			};
			if (anchor && anchor.parent && mod.m_controls && anchor.parent == mod.m_controls["SubMenu"])
			{
				return (anchor.parent);
			};
			return (mainRoot());
		}

		internal function uiParentAdd(child:Sprite, anchor:*):void
		{
			var parent:*;
			parent = resolveUiParent(anchor);
			if (!parent)
			{
				rootAdd(child);
				return;
			};
			try
			{
				parent.addChild(child);
			}
			catch (err:*)
			{
				log("uiParentAdd failed: " + err);
				rootAdd(child);
			};
		}

		internal static function toParentLocal(parent:*, globalPt:Point):Point
		{
			if (parent && globalPt)
			{
				try
				{
					return (parent.globalToLocal(globalPt));
				}
				catch (err:*)
				{
				};
			};
			return (toRootLocal(globalPt));
		}

		private static function toRootLocal(globalPt:Point):Point
		{
			var root:*;
			root = mainRoot();
			if (root && globalPt)
			{
				try
				{
					return (root.globalToLocal(globalPt));
				}
				catch (err:*)
				{
				};
			};
			return (globalPt ? globalPt.clone() : new Point(0, 0));
		}

		private static function mainRoot():*
		{
			var MainCls:Class;
			try
			{
				MainCls = EngineRefs.ssf2("Main") as Class;
				return (MainCls ? MainCls["Root"] : null);
			}
			catch (err:*)
			{
			};
			return (null);
		}

		internal static function gameWidth():Number
		{
			var MainCls:Class;
			try
			{
				MainCls = EngineRefs.ssf2("Main") as Class;
				if (MainCls && Number(MainCls["Width"]) > 0)
				{
					return (Number(MainCls["Width"]));
				};
			}
			catch (err:*)
			{
			};
			return (640);
		}

		internal static function gameHeight():Number
		{
			var MainCls:Class;
			try
			{
				MainCls = EngineRefs.ssf2("Main") as Class;
				if (MainCls && Number(MainCls["Height"]) > 0)
				{
					return (Number(MainCls["Height"]));
				};
			}
			catch (err:*)
			{
			};
			return (360);
		}

		internal static function focusField(field:TextField):void
		{
			var stage:*;
			stage = gameStage();
			if (stage && field)
			{
				stage.focus = field;
			};
		}

		internal static function gameStage():*
		{
			var root:*;
			try
			{
				root = mainRoot();
				if (root)
				{
					return (root["stage"]);
				};
			}
			catch (err:*)
			{
			};
			return (null);
		}
	}
}
