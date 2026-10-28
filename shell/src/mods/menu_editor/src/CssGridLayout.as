package
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.geom.Point;
	import flash.utils.Dictionary;

	import ssf2mm.shared.EngineRefs;

	/**
	 * Lays out the live Character Select grid: fits the cell size to the art and HUD, places,
	 * scales, spawns, and hides portrait icons, and writes the fitted layout into the mappings.
	 */
	public class CssGridLayout
	{
		private static const CSS_MENUS:Array = ["CurrentCharacterSelectMenu", "vsMenu", "trainingMenu", "classicMenu", "allstarMenu", "onlineCharacterMenu", "eventMatchCharacterMenu"];
		private static const MIN_CELL:Number = 8;

		private var mod:CssEditorMod;
		private var m_hudY:Number;
		private var m_fitLogged:int;
		private var m_spawnHold:Object;

		public function CssGridLayout(owner:CssEditorMod)
		{
			mod = owner;
			m_hudY = 0;
			m_fitLogged = -1;
		}

		internal function hideLeftoverIcons(rows:Array):void
		{
			var MC:Class;
			var menu:*;
			var hash:Object;
			var id:String;
			var keep:Object;
			var names:Array;
			var i:int;
			keep = {};
			for each (id in GridRows.flatten(rows))
			{
				keep[id] = true;
			};
			try
			{
				MC = EngineRefs.MenuController as Class;
			}
			catch (err:*)
			{
				return;
			};
			if (!MC)
			{
				return;
			};
			names = CSS_MENUS;
			i = 0;
			while (i < names.length)
			{
				try
				{
					menu = MC[names[i]];
					if (menu && menu.CharMCHash)
					{
						hash = menu.CharMCHash as Object;
						for (id in hash)
						{
							if (hash[id] && mod.m_roster.isCssExpansionId(id))
							{
								hideCssClip(hash[id] as DisplayObject);
							}
							else if (hash[id] && !keep[id])
							{
								hideCssClip(hash[id] as DisplayObject);
							};
						};
						try
						{
							hideCssExpansion(menu.CharSelectionIconsMC as DisplayObjectContainer, hash);
						}
						catch (iconErr:*)
						{
						};
					};
				}
				catch (menuErr:*)
				{
				};
				i++;
			};
		}

		private function stockGridCenterX():Number
		{
			var line:Array;
			var stockCols:int;
			var stockX:Number;
			var r:int;
			stockCols = 13;
			stockX = -51;
			if (mod.m_defaultPos)
			{
				stockX = Number(mod.m_defaultPos.x);
			};
			if (mod.m_defaults && mod.m_defaults.length > 0)
			{
				stockCols = 1;
				r = 0;
				while (r < mod.m_defaults.length)
				{
					line = mod.m_defaults[r] as Array;
					stockCols = Math.max(stockCols, line ? line.length : 0);
					r++;
				};
			};
			return (stockX + stockCols * 42 * 0.5);
		}

		private function gridLargerThanStock(cols:int, rows:int):Boolean
		{
			var line:Array;
			var stockCols:int;
			var stockRows:int;
			var r:int;
			stockCols = 13;
			stockRows = 4;
			if (mod.m_defaults && mod.m_defaults.length > 0)
			{
				stockRows = mod.m_defaults.length;
				stockCols = 1;
				r = 0;
				while (r < mod.m_defaults.length)
				{
					line = mod.m_defaults[r] as Array;
					stockCols = Math.max(stockCols, line ? line.length : 0);
					r++;
				};
			};
			return (cols > stockCols || rows > stockRows);
		}

		private function fittedCell(cols:int, rows:int, centerX:Number, boundsX:Number, boundsRight:Number, artTop:Number, hudY:Number, hudOk:Boolean):Number
		{
			var cell:Number;
			var limit:Number;
			var wLim:Number;
			var hLim:Number;
			var stockRows:int;
			var grow:Boolean;
			cell = 42;
			wLim = 999;
			hLim = 999;
			stockRows = 4;
			if (mod.m_defaults && mod.m_defaults.length > 0)
			{
				stockRows = mod.m_defaults.length;
			};
			grow = rows > 0 && rows < stockRows;
			if (cols > 0 && centerX > boundsX && boundsRight > centerX)
			{
				limit = (2 * (centerX - boundsX)) / (cols + 1);
				wLim = limit;
				if (cols > 1)
				{
					limit = (2 * (boundsRight - centerX)) / (cols - 1);
					if (limit < wLim)
					{
						wLim = limit;
					};
				};
				if (wLim < cell)
				{
					cell = wLim;
				};
			};
			if (hudOk && rows > 0 && hudY > artTop)
			{
				hLim = (hudY - artTop - 6) / rows;
				if (grow)
				{
					cell = hLim * 0.96;
					if (wLim < cell)
					{
						cell = wLim;
					};
				}
				else if (hLim < cell)
				{
					cell = hLim * 0.96;
				};
			};
			if (cell < MIN_CELL)
			{
				cell = MIN_CELL;
			};
			if (!grow && cell > 42)
			{
				cell = 42;
			};
			if (int(cell) != m_fitLogged)
			{
				m_fitLogged = int(cell);
				mod.cssLog("fit cell=" + int(cell) + " cols=" + cols + " rows=" + rows + " wLim=" + int(wLim) + " hLim=" + int(hLim) + " hudOk=" + (hudOk ? 1 : 0));
			};
			return (cell);
		}

		internal function layoutLiveCss(menu:*, mappings:Object, rows:Array):void
		{
			var icons:DisplayObjectContainer;
			var hash:Object;
			var fit:Object;
			var keep:Object;
			var placed:Array;
			var child:DisplayObject;
			var live:Dictionary;
			if (mod.m_paging.pageCount() == 2)
			{
				rows = mod.m_paging.dropNavId(rows, CssEditorMod.PAGE_PREV);
			};
			try
			{
				hash = menu.CharMCHash as Object;
				icons = menu.CharSelectionIconsMC as DisplayObjectContainer;
			}
			catch (hashErr:*)
			{
				return;
			};
			if (!hash || !icons)
			{
				return;
			};
			fit = fitGrid(menu, mappings, icons, rows);
			mod.m_icons = icons;
			mod.m_menu = menu;
			mod.m_cell = fit.cell;
			placed = rowsWithDragGap(rows);
			keep = {};
			live = new Dictionary(true);
			if (mod.m_dragging && mod.m_dragId)
			{
				keep[mod.m_dragId] = true;
			};
			placeGridIcons(placed, hash, icons, fit, keep, live);
			hideUnplacedIcons(hash, icons, keep, live);
			mod.m_icons = icons;
			mod.m_menu = menu;
			mod.m_cell = fit.cell;
			mod.m_originX = fit.originX;
			mod.m_originY = fit.originY;
			mod.m_maxCols = fit.maxCols;
			logGridFacts(placed, fit.cell, fit.originX, fit.originY, fit.hudY, fit.hudOk, fit.maxCols);
			pinReadyPrompt(menu);
			if (fit.hudOk && (mod.m_editing || fit.cell < 42))
			{
				writeFittedLayout(mappings, fit.cell, fit.originX, fit.originY);
			};
			if (mod.m_dragging && mod.m_dragId)
			{
				child = mod.m_input.iconClip(mod.m_dragId);
				if (child)
				{
					child.visible = true;
					raiseIcon(child);
				};
			}
			else if (!mod.m_editing)
			{
				mod.m_hands.raiseHands(menu);
			};
			mod.m_hands.scalePlayerCursors(menu, fit.scale);
		}

		/** Cell size and grid origin for rows on this menu: {cell, scale, originX, originY, hudY, hudOk, maxCols, nRows}. */
		private function fitGrid(menu:*, mappings:Object, icons:DisplayObjectContainer, rows:Array):Object
		{
			var bounds:Object;
			var maxCols:int;
			var nRows:int;
			var cell:Number;
			var availW:Number;
			var originX:Number;
			var originY:Number;
			var stockY:Number;
			var artTop:Number;
			var hudY:Number;
			var hudOk:Boolean;
			var box:DisplayObject;
			var centerX:Number;
			var boundsX:Number;
			var boundsRight:Number;
			maxCols = portraitCols(rows);
			nRows = portraitRows(rows);
			bounds = mappings.character_select_screen.chip_bounds;
			availW = 610;
			if (bounds && bounds.width)
			{
				availW = Number(bounds.width);
			};
			stockY = 23;
			if (mod.m_defaultPos)
			{
				stockY = Number(mod.m_defaultPos.y);
			};
			artTop = stockY - 21;
			extendChipBounds(mappings, artTop);
			originY = stockY;
			hudY = cssHudTopInIcons(menu, icons, originY + 160);
			if (hudY > originY + 80 && hudY < originY + 320)
			{
				m_hudY = hudY;
			}
			else if (m_hudY > originY + 80)
			{
				hudY = m_hudY;
			};
			box = null;
			try
			{
				if (menu.CharSelectionBoxes && menu.CharSelectionBoxes.length > 0)
				{
					box = menu.CharSelectionBoxes[0] as DisplayObject;
				};
			}
			catch (boxErr:*)
			{
				box = null;
			};
			hudOk = box != null && hudY > originY + 80 && hudY < originY + 320;
			centerX = stockGridCenterX();
			boundsX = -105;
			boundsRight = boundsX + availW;
			if (bounds && !isNaN(Number(bounds.x)))
			{
				boundsX = Number(bounds.x);
				boundsRight = boundsX + availW;
			};
			cell = fittedCell(maxCols, nRows, centerX, boundsX, boundsRight, artTop, hudY, hudOk);
			originY = artTop + cell * 0.5;
			if (int(originY) != int(mod.m_originY))
			{
				mod.cssLog("fit oy=" + int(originY) + " top=" + int(artTop) + " cell=" + int(cell) + " rows=" + nRows);
			};
			originX = centerX - maxCols * cell * 0.5;
			if (cell < 42)
			{
				originX = (boundsX + boundsRight) * 0.5 - (maxCols - 1) * cell * 0.5;
			};
			return ({
				"cell": cell,
				"scale": cell / 42,
				"originX": originX,
				"originY": originY,
				"hudY": hudY,
				"hudOk": hudOk,
				"maxCols": maxCols,
				"nRows": nRows
			});
		}

		/** Shows, scales, and positions every icon in placed; marks each id in keep and each clip in live. */
		private function placeGridIcons(placed:Array, hash:Object, icons:DisplayObjectContainer, fit:Object, keep:Object, live:Dictionary):void
		{
			var vis:Array;
			var child:DisplayObject;
			var id:String;
			var r:int;
			var c:int;
			var p:int;
			var cell:Number;
			var scale:Number;
			var shift:Number;
			cell = fit.cell;
			scale = fit.scale;
			r = 0;
			while (r < placed.length)
			{
				vis = (placed[r] as Array) || [];
				shift = (int(fit.maxCols) - slotLen(vis)) * cell * 0.5;
				c = 0;
				p = 0;
				while (c < vis.length)
				{
					id = String(vis[c]);
					if (id == "cxp" || id == "xp")
					{
						c++;
						continue;
					};
					if (!id)
					{
						p++;
						c++;
						continue;
					};
					keep[id] = true;
					child = hash[id] as DisplayObject;
					if (!child && mod.m_paging.isPageNav(id))
					{
						child = mod.m_paging.pageClip(icons, id);
					};
					if (!child && m_spawnHold && m_spawnHold[id])
					{
						p++;
						c++;
						continue;
					};
					if (!child)
					{
						child = spawnCssIcon(icons, hash, id);
					};
					if (child)
					{
						live[child] = true;
						placeGridIcon(child, id, Number(fit.originX) + shift + p * cell, Number(fit.originY) + r * cell, scale);
					};
					p++;
					c++;
				};
				r++;
			};
		}

		private function placeGridIcon(child:DisplayObject, id:String, x:Number, y:Number, scale:Number):void
		{
			child.visible = true;
			try
			{
				child["mouseEnabled"] = true;
				child["mouseChildren"] = !mod.m_paging.isPageNav(id);
			}
			catch (mouseErr:*)
			{
			};
			if (child.scaleX != scale)
			{
				child.scaleX = scale;
			};
			if (child.scaleY != scale)
			{
				child.scaleY = scale;
			};
			child.alpha = (mod.m_editing && mod.m_mode == CssEditorMod.MODE_REMOVE && mod.m_removeIds && mod.m_removeIds[id]) ? 0.4 : 1;
			if (!(mod.m_dragging && mod.m_dragId == id))
			{
				child.x = x;
				child.y = y;
			}
			else
			{
				raiseIcon(child);
			};
		}

		/** Page arrows, the dragged icon, and every hash clip that is not in keep. */
		private function hideUnplacedIcons(hash:Object, icons:DisplayObjectContainer, keep:Object, live:Dictionary):void
		{
			var child:DisplayObject;
			var id:String;
			if (mod.m_paging.pageCount() <= 1)
			{
				mod.m_paging.hidePageClips();
			}
			else if (mod.m_pageClips)
			{
				if (keep[CssEditorMod.PAGE_PREV])
				{
					raiseIcon(mod.m_pageClips[CssEditorMod.PAGE_PREV] as DisplayObject);
				};
				if (keep[CssEditorMod.PAGE_NEXT])
				{
					raiseIcon(mod.m_pageClips[CssEditorMod.PAGE_NEXT] as DisplayObject);
				};
			};
			if (mod.m_dragging && mod.m_dragId)
			{
				child = mod.m_input.iconClip(mod.m_dragId);
				if (child)
				{
					live[child] = true;
					child.visible = true;
					raiseIcon(child);
				};
			};
			for (id in hash)
			{
				if (hash[id] && mod.m_roster.isCssExpansionId(id))
				{
					hideCssClip(hash[id] as DisplayObject);
				}
				else if (hash[id] && !keep[id])
				{
					hideCssClip(hash[id] as DisplayObject);
				};
			};
			retireStrayIcons(icons, live);
			hideCssExpansion(icons, hash);
		}

		private function rowsWithDragGap(rows:Array):Array
		{
			var out:Array;
			var cell:Object;
			var child:DisplayObject;
			var g:Point;
			var r:int;
			var c:int;
			var line:Array;
			var next:Array;
			var id:String;
			var rowIndex:int;
			var col:int;
			if (!(mod.m_dragging && mod.m_dragId && mod.m_icons && mod.m_icons.stage))
			{
				return (rows);
			};
			child = mod.m_input.iconClip(mod.m_dragId);
			if (!child)
			{
				return (rows);
			};
			try
			{
				g = child.localToGlobal(new Point(0, 0));
				cell = mod.m_input.cellAt(g.x, g.y);
			}
			catch (err:*)
			{
				return (rows);
			};
			if (!cell)
			{
				return (rows);
			};
			out = [];
			r = 0;
			while (r < rows.length)
			{
				line = rows[r] as Array;
				next = [];
				c = 0;
				while (line && c < line.length)
				{
					id = String(line[c]);
					if (id != mod.m_dragId)
					{
						next.push(id);
					};
					c++;
				};
				out.push(next);
				r++;
			};
			if (String(cell.mode) == "newrow")
			{
				c = 0;
				r = 0;
				while (r < out.length)
				{
					line = out[r] as Array;
					if (line && line.length > 0)
					{
						c++;
					};
					r++;
				};
				if (c >= CssEditorMod.MAX_ROWS)
				{
					return (rows);
				};
				out.push([""]);
				return (out);
			};
			rowIndex = int(cell.row);
			while (out.length <= rowIndex)
			{
				out.push([]);
			};
			line = out[rowIndex] as Array;
			if (!line)
			{
				line = [];
				out[rowIndex] = line;
			};
			col = sameRowInsertCol(rows, mod.m_dragId, int(cell.row), int(cell.col));
			if (col > line.length)
			{
				col = line.length;
			};
			line.splice(col, 0, "");
			return (out);
		}

		private function slotLen(line:Array):int
		{
			var c:int;
			var n:int;
			var id:String;
			n = 0;
			c = 0;
			while (line && c < line.length)
			{
				id = String(line[c]);
				if (id != "cxp" && id != "xp")
				{
					n++;
				};
				c++;
			};
			return (n);
		}

		private function sameRowInsertCol(rows:Array, id:String, cellRow:int, cellCol:int):int
		{
			var r:int;
			var c:int;
			var line:Array;
			if (cellCol < 0)
			{
				cellCol = 0;
			};
			r = 0;
			while (rows && r < rows.length)
			{
				line = rows[r] as Array;
				if (line)
				{
					c = line.indexOf(id);
					if (c >= 0)
					{
						if (line.length > 1 && r == cellRow && c < cellCol)
						{
							cellCol--;
						};
						break;
					};
				};
				r++;
			};
			if (cellCol < 0)
			{
				cellCol = 0;
			};
			return (cellCol);
		}

		internal function portraitLen(line:Array):int
		{
			var c:int;
			var n:int;
			var id:String;
			n = 0;
			c = 0;
			while (line && c < line.length)
			{
				id = String(line[c]);
				if (id && id != "cxp" && id != "xp")
				{
					n++;
				};
				c++;
			};
			return (n);
		}

		private function portraitCols(rows:Array):int
		{
			var max:int;
			var n:int;
			var r:int;
			max = 1;
			if (!rows)
			{
				return (max);
			};
			r = 0;
			while (r < rows.length)
			{
				n = portraitLen(rows[r] as Array);
				if (n > max)
				{
					max = n;
				};
				r++;
			};
			return (max);
		}

		private function portraitRows(rows:Array):int
		{
			var n:int;
			var r:int;
			n = 0;
			if (!rows)
			{
				return (1);
			};
			r = 0;
			while (r < rows.length)
			{
				if (portraitLen(rows[r] as Array) > 0)
				{
					n++;
				};
				r++;
			};
			if (n < 1)
			{
				n = 1;
			};
			return (n);
		}

		private function retireStrayIcons(icons:DisplayObjectContainer, live:Dictionary):void
		{
			var i:int;
			var child:DisplayObject;
			var id:String;
			if (!icons)
			{
				return;
			};
			i = 0;
			while (i < icons.numChildren)
			{
				child = icons.getChildAt(i);
				i++;
				if (!child || live[child] || isPlayerChipClip(child))
				{
					continue;
				};
				id = readCharId(child);
				if (!id)
				{
					continue;
				};
				if (!mod.m_paging.isPageNav(id) && !clipHasCharacterId(child))
				{
					continue;
				};
				hideCssClip(child);
			};
		}

		private function clipHasCharacterId(child:DisplayObject):Boolean
		{
			try
			{
				return (child && child["characterID"] ? true : false);
			}
			catch (err:*)
			{
			};
			return (false);
		}

		internal function hideCssClip(child:DisplayObject):void
		{
			if (!child)
			{
				return;
			};
			child.visible = false;
			child.x = -4000;
			child.y = -4000;
			try
			{
				child["mouseEnabled"] = false;
				child["mouseChildren"] = false;
			}
			catch (err:*)
			{
			};
		}

		private function hideCssExpansion(icons:DisplayObjectContainer, hash:Object):void
		{
			var i:int;
			var child:DisplayObject;
			var id:String;
			if (hash)
			{
				hideCssClip(hash["cxp"] as DisplayObject);
				hideCssClip(hash["xp"] as DisplayObject);
			};
			if (!icons)
			{
				return;
			};
			i = 0;
			while (i < icons.numChildren)
			{
				child = icons.getChildAt(i);
				if (isPlayerChipClip(child))
				{
					i++;
					continue;
				};
				id = readCharId(child);
				if (mod.m_roster.isCssExpansionId(id))
				{
					hideCssClip(child);
				};
				i++;
			};
		}

		private function isPlayerChipClip(child:DisplayObject):Boolean
		{
			var name:String;
			if (!child)
			{
				return (false);
			};
			name = child.name || "";
			if (name.indexOf("chip") == 0)
			{
				return (true);
			};
			if (name.indexOf("hand") >= 0)
			{
				return (true);
			};
			return (false);
		}

		internal function readCharId(child:DisplayObject):String
		{
			if (!child)
			{
				return ("");
			};
			try
			{
				if (child["characterID"])
				{
					return (String(child["characterID"]));
				};
			}
			catch (err:*)
			{
			};
			if (child.name && child.name != "")
			{
				return (child.name);
			};
			return ("");
		}

		private function cssHudTopInIcons(menu:*, icons:DisplayObjectContainer, fallback:Number):Number
		{
			var box:DisplayObject;
			var pt:Point;
			try
			{
				if (menu.CharSelectionBoxes && menu.CharSelectionBoxes.length > 0)
				{
					box = menu.CharSelectionBoxes[0] as DisplayObject;
				};
				if (!box && menu.CharSelectionMC)
				{
					box = menu.CharSelectionMC["display1"] as DisplayObject;
				};
				if (box && box.parent && icons)
				{
					pt = icons.globalToLocal(box.parent.localToGlobal(new Point(box.x, box.y)));
					return (pt.y);
				};
			}
			catch (err:*)
			{
			};
			return (fallback);
		}

		private function spawnCssIcon(icons:DisplayObjectContainer, hash:Object, id:String):DisplayObject
		{
			var mc:MovieClip;
			if (!id || id == "cxp")
			{
				return (null);
			};
			if (!m_spawnHold)
			{
				m_spawnHold = {};
			};
			if (m_spawnHold[id])
			{
				return (null);
			};
			m_spawnHold[id] = true;
			try
			{
				mc = EditorEngine.libraryMC(id + "_select");
				if (mc)
				{
					try
					{
						mc.gotoAndStop(1);
					}
					catch (err:*)
					{
					};
					try
					{
						mc["characterID"] = id;
					}
					catch (idErr:*)
					{
					};
					hash[id] = mc;
					icons.addChild(mc);
				};
			}
			finally
			{
				m_spawnHold[id] = false;
			};
			return (mc);
		}

		private function extendChipBounds(mappings:Object, artTop:Number):void
		{
			var screen:Object;
			var bounds:Object;
			var bottom:Number;
			if (!mappings || !mappings.character_select_screen || isNaN(artTop))
			{
				return;
			};
			screen = mappings.character_select_screen;
			bounds = screen.chip_bounds;
			if (!bounds || isNaN(Number(bounds.y)) || isNaN(Number(bounds.height)))
			{
				return;
			};
			if (Number(bounds.y) <= artTop)
			{
				return;
			};
			bottom = Number(bounds.y) + Number(bounds.height);
			bounds.y = artTop;
			bounds.height = bottom - artTop;
			mod.cssLog("chip bounds y=" + int(artTop) + " h=" + int(bounds.height));
		}

		private function writeFittedLayout(mappings:Object, cell:Number, originX:Number, originY:Number):void
		{
			var screen:Object;
			if (!mappings || !mappings.character_select_screen)
			{
				return;
			};
			screen = mappings.character_select_screen;
			if (!screen.icon_size)
			{
				screen.icon_size = {};
			};
			if (!screen.position)
			{
				screen.position = {};
			};
			screen.icon_size.width = cell;
			screen.icon_size.height = cell;
			screen.position.x = originX;
			screen.position.y = originY;
		}

		/** Ready to Fight stays on screen after the grid moves. */
		private function pinReadyPrompt(menu:*):void
		{
			var sub:DisplayObjectContainer;
			var names:Array;
			var clip:DisplayObject;
			var i:int;
			var pt:Point;
			try
			{
				if (menu && menu["updateGameIsReady"])
				{
					menu["updateGameIsReady"]();
				};
			}
			catch (readyErr:*)
			{
			};
			sub = menu ? menu["SubMenu"] as DisplayObjectContainer : null;
			if (!sub)
			{
				return;
			};
			names = ["readyToFight", "ready", "pressStart", "press_start", "startPrompt", "txtReady", "mcReady"];
			i = 0;
			while (i < names.length)
			{
				clip = sub.getChildByName(String(names[i]));
				if (clip)
				{
					pt = clip.localToGlobal(new Point(0, 0));
					if (pt.y < 8 || pt.y > 320)
					{
						clip.y = clip.y + (300 - pt.y);
					};
					mod.cssLog("ready prompt name=" + clip.name + " vis=" + (clip.visible ? 1 : 0) + " y=" + int(clip.y) + " gy=" + int(pt.y));
					return;
				};
				i++;
			};
		}

		private function logGridFacts(placed:Array, cell:Number, originX:Number, originY:Number, hudY:Number, hudOk:Boolean, maxCols:int):void
		{
			var lens:String;
			var line:Array;
			var id:String;
			var r:int;
			var c:int;
			var nav:int;
			if (mod.m_loggedGrid)
			{
				return;
			};
			mod.m_loggedGrid = true;
			lens = "";
			nav = 0;
			r = 0;
			while (placed && r < placed.length)
			{
				line = placed[r] as Array;
				if (r > 0)
				{
					lens += ",";
				};
				lens += String(line ? line.length : 0);
				c = 0;
				while (line && c < line.length)
				{
					id = String(line[c]);
					if (mod.m_paging.isPageNav(id))
					{
						nav++;
					};
					c++;
				};
				r++;
			};
			mod.cssLog("grid rows=" + (placed ? placed.length : 0) + " cols=" + maxCols + " cell=" + int(cell) + " larger=" + (gridLargerThanStock(maxCols, placed ? placed.length : 0) ? 1 : 0) + " ox=" + int(originX) + " oy=" + int(originY) + " hud=" + int(hudY) + " hudOk=" + (hudOk ? 1 : 0) + " nav=" + nav + " lens=" + lens + " " + mod.m_chrome.navPlace() + " icon=" + mod.m_chrome.iconSpot());
		}

		internal function raiseIcon(child:DisplayObject):void
		{
			if (child && child.parent)
			{
				try
				{
					child.parent.setChildIndex(child, child.parent.numChildren - 1);
				}
				catch (err:*)
				{
				};
			};
			mod.m_hands.raisePrimaryHand(mod.m_menu);
		}
	}
}
