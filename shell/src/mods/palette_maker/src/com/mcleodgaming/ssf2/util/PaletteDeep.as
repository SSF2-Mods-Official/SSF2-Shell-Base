package com.mcleodgaming.ssf2.util
{
   import com.mcleodgaming.ssf2.modhost.*;
   import flash.display.*;
   import flash.geom.*;
   import flash.utils.getDefinitionByName;
   import flash.utils.getQualifiedClassName;

   public class PaletteDeep
   {
      private static var paletteRect:Rectangle = new Rectangle();
      private static var palettePoint:Point = new Point();
      private static var s_pristineBitmaps:flash.utils.Dictionary = new flash.utils.Dictionary(true);
      private static var s_deepPaletteCaches:flash.utils.Dictionary = new flash.utils.Dictionary(true);
      private static var s_shapeGraphicsCaches:flash.utils.Dictionary = new flash.utils.Dictionary(true);
      private static var s_shapeBitmapOriginals:flash.utils.Dictionary = new flash.utils.Dictionary(true);


      private static var s_print:Function = null;
      private static var s_printTried:Boolean = false;

      private static function printer() : Function
      {
         var API:Class = null;
         if(s_printTried)
         {
            return s_print;
         }
         s_printTried = true;
         API = flash.utils.getDefinitionByName("com.mcleodgaming.ssf2.api.SSF2API") as Class;
         if(API && API["print"] is Function)
         {
            s_print = API["print"];
         }
         return s_print;
      }

      public static function note(msg:String) : void
      {
         var fn:Function = printer();
         var line:String = msg == null ? "" : String(msg);
         trace(line);
         if(fn != null)
         {
            fn(line);
         }
      }

      private static function hex(n:uint) : String
      {
         var s:String = n.toString(16);
         while(s.length < 8)
         {
            s = "0" + s;
         }
         return s;
      }

      public static function describeArt(node:DisplayObject) : Object
      {
         var info:Object = {
            "bitmaps":0,
            "shapes":0,
            "gfx":0,
            "kids":0
         };
         describeArtWalk(node,8,info);
         return info;
      }

      private static function describeArtWalk(node:DisplayObject, depth:int, info:Object) : void
      {
         var container:DisplayObjectContainer = null;
         var g:Graphics = null;
         var src:Vector.<IGraphicsData> = null;
         var i:int = 0;
         if(!node || depth < 0 || !info)
         {
            return;
         }
         if(node is Bitmap)
         {
            info.bitmaps = int(info.bitmaps) + 1;
            return;
         }
         if(node is Shape)
         {
            info.shapes = int(info.shapes) + 1;
            g = (node as Shape).graphics;
         }
         else if(node is Sprite)
         {
            g = (node as Sprite).graphics;
            container = node as DisplayObjectContainer;
         }
         if(g)
         {
            try
            {
               src = g.readGraphicsData(false);
            }
            catch(readErr:Error)
            {
               src = null;
            }
            if(src)
            {
               info.gfx = int(info.gfx) + src.length;
            }
         }
         if(!container)
         {
            return;
         }
         info.kids = int(info.kids) + container.numChildren;
         i = 0;
         while(i < container.numChildren && i < 40)
         {
            describeArtWalk(container.getChildAt(i),depth - 1,info);
            i++;
         }
      }

      public static function rasterRecolor(mc:MovieClip, paletteData:Object) : Object
      {
         var bounds:Rectangle = null;
         var bmd:BitmapData = null;
         var bmp:Bitmap = null;
         var drawMatrix:Matrix = null;
         var i:int = 0;
         var child:DisplayObject = null;
         var hits:int = 0;
         var result:Object = {
            "w":0,
            "h":0,
            "hits":0,
            "kids":0
         };
         if(!mc || !paletteData)
         {
            return result;
         }
         i = mc.numChildren - 1;
         while(i >= 0)
         {
            child = mc.getChildAt(i);
            if(child && child.name == "pmRaster")
            {
               mc.removeChild(child);
            }
            i--;
         }
         bounds = mc.getBounds(mc);
         if(bounds.width < 1 || bounds.height < 1 || bounds.width > 512 || bounds.height > 512)
         {
            result.w = bounds.width;
            result.h = bounds.height;
            return result;
         }
         result.kids = mc.numChildren;
         bmd = new BitmapData(Math.ceil(bounds.width),Math.ceil(bounds.height),true,0);
         drawMatrix = new Matrix();
         drawMatrix.translate(-bounds.x,-bounds.y);
         try
         {
            bmd.draw(mc,drawMatrix,null,null,null,true);
         }
         catch(drawErr:Error)
         {
            bmd.dispose();
            return result;
         }
         hits = countRgbHits(bmd,paletteData);
         replacePaletteHelper(bmd,paletteData,true);
         bmp = new Bitmap(bmd,"auto",true);
         bmp.name = "pmRaster";
         bmp.x = bounds.x;
         bmp.y = bounds.y;
         mc.addChild(bmp);
         result.w = bmd.width;
         result.h = bmd.height;
         result.hits = hits;
         return result;
      }

      public static function countRgbHits(bd:BitmapData, paletteData:Object) : int
      {
         var colors:Array = null;
         var repls:Array = null;
         var map:Object = null;
         var pixels:Vector.<uint> = null;
         var i:int = 0;
         var n:int = 0;
         var hits:int = 0;
         var pix:uint = 0;
         var key:String = null;
         if(!bd || !paletteData || !(paletteData.colors is Array) || !(paletteData.replacements is Array))
         {
            return 0;
         }
         colors = paletteData.colors as Array;
         repls = paletteData.replacements as Array;
         map = {};
         i = 0;
         while(i < colors.length && i < repls.length)
         {
            if(colors[i] != repls[i])
            {
               map[String(uint(colors[i]) & 0xFFFFFF)] = true;
            }
            i++;
         }
         pixels = bd.getVector(bd.rect);
         n = int(pixels.length);
         i = 0;
         while(i < n)
         {
            pix = pixels[i];
            if((pix >> 24 & 0xFF) != 0)
            {
               key = String(pix & 0xFFFFFF);
               if(map.hasOwnProperty(key))
               {
                  hits++;
               }
            }
            i++;
         }
         return hits;
      }


      public static function tryToGotoAndStop(mc:MovieClip, frame:*, cache:Boolean = false) : void
      {
         if(!mc)
         {
            return;
         }
         if(frame is int || frame is Number)
         {
            if(frame > 0 && frame <= mc.totalFrames)
            {
               try
               {
                  mc.gotoAndStop(frame);
               }
               catch(numErr:*)
               {
               }
            }
         }
         else if(frame is String)
         {
            safeGotoAndStop(mc,String(frame),cache);
         }
      }

      public static function safeGotoAndStop(mc:MovieClip, id:String, cache:Boolean = false) : Boolean
      {
         var i:int = 0;
         var sceneName:String = null;
         if(!mc || !id || id.length <= 0)
         {
            return false;
         }
         try
         {
            if(Boolean(mc.currentScene) && mc.currentScene.name == id)
            {
               return true;
            }
            if(hasLabel(mc,id,cache))
            {
               mc.gotoAndStop(id);
               return true;
            }
            if(Boolean(mc.scenes))
            {
               i = 0;
               while(i < mc.scenes.length)
               {
                  sceneName = mc.scenes[i].name;
                  if(sceneName == id)
                  {
                     mc.gotoAndStop(1,id);
                     return true;
                  }
                  i++;
               }
            }
         }
         catch(err:*)
         {
         }
         return false;
      }

      public static function setColorFilterCharacter(mc:MovieClip, team_id:int, statsName:String, costumeID:int = -1, PAPalette:Boolean = false, paletteSmoothing:Boolean = false) : void
      {
         if(statsName == "xp")
         {
            statsName = Stats.resolveExpansionStatsName(ResourceManager.ActiveXpExpansion);
         }
         var colorStr:String = Utils.getColorString(team_id);
         var colorObj:Object = ResourceManager.getCostume(statsName,colorStr,costumeID);
         if(colorObj == null)
         {
            colorObj = Utils.getCostumeObject();
         }
         ModHost.runHook(ModHooks.CSS_APPLY_COSTUME,{
            "mc":mc,
            "teamId":team_id,
            "statsName":statsName,
            "costumeID":costumeID,
            "colorObj":colorObj,
            "PAPalette":PAPalette
         });
         if(colorObj != null)
         {
            Utils.setColorFilter(mc,colorObj);
         }
         if(PAPalette)
         {
            restoreDeepPaletteOriginals(mc);
            replacePaletteDeep(mc,Boolean(ModHost.door(ModPatches.PALETTE_SHOULD_COMBINE_FORM_PALETTE,[statsName],false)) ? combinePaletteBlocks(colorObj.paletteSwap,colorObj.paletteSwapPA) : colorObj.paletteSwapPA,12,true,paletteSmoothing);
         }
         else if(ResourceManager.isExpansionStatsName(statsName))
         {
            restoreDeepPaletteOriginals(mc);
            replacePaletteDeep(mc,colorObj.paletteSwap,12,true,paletteSmoothing);
         }
         else
         {
            restorePaletteOriginals(mc,2);
            Utils.replacePalette(mc,colorObj.paletteSwap,2,true,paletteSmoothing);
         }
         applyCostumeMcName(mc,statsName,colorObj);
      }

      public static function getCachedOriginalBitmapData(bitmap:Bitmap, deepRoot:DisplayObject = null) : BitmapData
      {
         var bd:BitmapData = null;
         var node:DisplayObject = null;
         var mc:MovieClip = null;
         var cache:flash.utils.Dictionary = null;
         var original:BitmapData = null;
         if(!bitmap || !bitmap.bitmapData)
         {
            return null;
         }
         bd = bitmap.bitmapData;
         node = bitmap.parent;
         while(Boolean(node))
         {
            if(node is MovieClip && ("__cachedPalette" in (node as MovieClip)) && Boolean((node as MovieClip).__cachedPalette))
            {
               mc = node as MovieClip;
               original = mc.__cachedPalette[bd] as BitmapData;
               if(Boolean(original))
               {
                  return original;
               }
            }
            node = node.parent;
         }
         original = s_shapeBitmapOriginals[bd] as BitmapData;
         if(Boolean(original))
         {
            return original;
         }
         if(Boolean(deepRoot) && Boolean(s_deepPaletteCaches))
         {
            cache = s_deepPaletteCaches[deepRoot] as flash.utils.Dictionary;
            if(Boolean(cache))
            {
               original = cache[bd] as BitmapData;
               if(Boolean(original))
               {
                  return original;
               }
            }
         }
         if(Boolean(s_deepPaletteCaches))
         {
            for each(cache in s_deepPaletteCaches)
            {
               if(Boolean(cache))
               {
                  original = cache[bd] as BitmapData;
                  if(Boolean(original))
                  {
                     return original;
                  }
               }
            }
         }
         return null;
      }

      public static function restoreDeepPaletteOriginals(root:DisplayObject, recursion:int = 12) : void
      {
         var cache:flash.utils.Dictionary = null;
         if(!root)
         {
            return;
         }
         cache = s_deepPaletteCaches[root] as flash.utils.Dictionary;
         if(!cache)
         {
            return;
         }
         restoreDeepPaletteOriginalsWalk(root,cache,recursion);
      }

      public static function restoreDeepPaletteOriginalsWalk(node:DisplayObject, cache:flash.utils.Dictionary, depth:int) : void
      {
         var bmp:Bitmap = null;
         var bd:BitmapData = null;
         var original:BitmapData = null;
         var container:DisplayObjectContainer = null;
         var i:int = 0;
         if(!node || depth < 0)
         {
            return;
         }
         if(node is Bitmap)
         {
            bmp = node as Bitmap;
            bd = bmp.bitmapData;
            if(!isUsableBitmapData(bd))
            {
               return;
            }
            original = cache[bd] as BitmapData;
            if(Boolean(original) && Boolean(isUsableBitmapData(original)))
            {
               bd.lock();
               bd.fillRect(bd.rect,0);
               bd.draw(original);
               bd.unlock();
            }
            return;
         }
         container = node as DisplayObjectContainer;
         if(!container)
         {
            return;
         }
         i = 0;
         while(i < container.numChildren)
         {
            restoreDeepPaletteOriginalsWalk(container.getChildAt(i),cache,depth - 1);
            i++;
         }
      }

      public static function restorePaletteOriginals(mc:MovieClip, recursion:int = 2) : void
      {
         var i:int = 0;
         var bitmap:Bitmap = null;
         if(!mc)
         {
            return;
         }
         i = 0;
         while(i < mc.numChildren)
         {
            if(mc.getChildAt(i) is Bitmap)
            {
               bitmap = mc.getChildAt(i) as Bitmap;
               if(("__cachedPalette" in mc) && Boolean(mc.__cachedPalette) && Boolean(mc.__cachedPalette[bitmap.bitmapData]))
               {
                  bitmap.bitmapData.lock();
                  bitmap.bitmapData.fillRect(bitmap.bitmapData.rect,0);
                  bitmap.bitmapData.draw(mc.__cachedPalette[bitmap.bitmapData]);
                  bitmap.bitmapData.unlock();
               }
            }
            else if(mc.getChildAt(i) is MovieClip && recursion > 0)
            {
               restorePaletteOriginals(mc.getChildAt(i) as MovieClip,recursion - 1);
            }
            i++;
         }
      }

      public static function combinePaletteBlocks(a:Object, b:Object) : Object
      {
         return ModHost.applyPatch(ModPatches.COMBINE_PALETTE_BLOCKS,[a,b],combinePaletteBlocksStock) as Object;
      }

      /** Merge two palette blocks in first-seen color order; the later block wins on a shared source color. */
      public static function combinePaletteBlocksStock(a:Object, b:Object) : Object
      {
         var block:Object = null;
         var i:int = 0;
         var key:String = null;
         var colors:Array = [];
         var replacements:Array = [];
         var seen:Object = {};
         var order:Array = [];
         for each(block in [a,b])
         {
            if(!(!block || !(block.colors is Array) || !(block.replacements is Array)))
            {
               i = 0;
               while(i < block.colors.length && i < block.replacements.length)
               {
                  key = String(uint(block.colors[i]));
                  if(!seen.hasOwnProperty(key))
                  {
                     order.push(key);
                  }
                  seen[key] = uint(block.replacements[i]);
                  i++;
               }
            }
         }
         for each(key in order)
         {
            colors.push(uint(key));
            replacements.push(uint(seen[key]));
         }
         return {
            "colors":colors,
            "replacements":replacements
         };
      }

      public static function applyCostumeMcName(root:DisplayObject, statsName:String, costume:Object) : void
      {
         var names:Array = null;
         var active:String = null;
         var name:String = null;
         var found:DisplayObject = null;
         if(!root || !statsName)
         {
            return;
         }
         if(!costume || !costume.mcName)
         {
            return;
         }
         active = String(costume.mcName).replace(/^\s+|\s+$/g,"");
         if(!active || active.length == 0)
         {
            return;
         }
         names = collectMcNamesForCharacter(statsName);
         if(!names || names.length == 0)
         {
            return;
         }
         for each(name in names)
         {
            found = findDisplayObjectByName(root,name,32);
            if(Boolean(found))
            {
               found.visible = name == active;
            }
         }
      }

      public static function findCostumeIndexByMcName(statsName:String, mcName:String) : int
      {
         var list:Array = null;
         var i:int = 0;
         var costume:Object = null;
         var name:String = null;
         if(!statsName || !mcName)
         {
            return -1;
         }
         mcName = String(mcName).replace(/^\s+|\s+$/g,"");
         try
         {
            statsName = ResourceManager.resolveCostumeStatsName(statsName);
            list = ResourceManager.getAllCostumes(statsName,null,false);
         }
         catch(err:Error)
         {
            return -1;
         }
         if(!list)
         {
            return -1;
         }
         i = 0;
         while(i < list.length)
         {
            costume = list[i];
            if(Boolean(costume) && Boolean(costume.mcName))
            {
               name = String(costume.mcName).replace(/^\s+|\s+$/g,"");
               if(name == mcName)
               {
                  return i;
               }
            }
            i++;
         }
         return -1;
      }

      public static function collectMcNamesForCharacter(statsName:String) : Array
      {
         var list:Array = null;
         var costume:Object = null;
         var name:String = null;
         var out:Array = [];
         var seen:Object = {};
         if(!statsName)
         {
            return out;
         }
         try
         {
            list = ResourceManager.getAllCostumes(statsName,null,true);
         }
         catch(err:Error)
         {
            list = null;
         }
         if(!list)
         {
            return out;
         }
         for each(costume in list)
         {
            if(!(!costume || !costume.mcName))
            {
               name = String(costume.mcName).replace(/^\s+|\s+$/g,"");
               if(!(!name || name.length == 0 || Boolean(seen[name])))
               {
                  seen[name] = true;
                  out.push(name);
               }
            }
         }
         out.sort();
         return out;
      }

      public static function findDisplayObjectByName(node:DisplayObject, clipName:String, depth:int = 16) : DisplayObject
      {
         var container:DisplayObjectContainer = null;
         var i:int = 0;
         var child:DisplayObject = null;
         var found:DisplayObject = null;
         var prop:* = undefined;
         if(!node || !clipName || depth < 0)
         {
            return null;
         }
         if(node.name == clipName)
         {
            return node;
         }
         container = node as DisplayObjectContainer;
         if(!container)
         {
            return null;
         }
         try
         {
            if(Object(container).hasOwnProperty(clipName))
            {
               prop = container[clipName];
               if(prop is DisplayObject)
               {
                  return prop as DisplayObject;
               }
            }
         }
         catch(propErr:Error)
         {
         }
         try
         {
            child = container.getChildByName(clipName);
            if(Boolean(child))
            {
               return child;
            }
         }
         catch(nameErr:Error)
         {
         }
         i = 0;
         while(i < container.numChildren)
         {
            child = container.getChildAt(i);
            found = findDisplayObjectByName(child,clipName,depth - 1);
            if(Boolean(found))
            {
               return found;
            }
            i++;
         }
         return null;
      }

      public static function replacePaletteDeep(root:DisplayObject, paletteData:Object, recursion:int = 12, cacheOriginal:Boolean = false, smoothing:Boolean = false, rgbOnly:Boolean = false) : void
      {
         ModHost.applyPatch(ModPatches.REPLACE_PALETTE_DEEP,[root,paletteData,recursion,cacheOriginal,smoothing,rgbOnly],replacePaletteDeepStock);
      }

      public static function replacePaletteDeepStock(root:DisplayObject, paletteData:Object, recursion:int = 12, cacheOriginal:Boolean = false, smoothing:Boolean = false, rgbOnly:Boolean = false) : void
      {
         var cache:flash.utils.Dictionary = null;
         if(!root || !paletteData && !cacheOriginal)
         {
            return;
         }
         cache = null;
         if(cacheOriginal)
         {
            cache = s_deepPaletteCaches[root] as flash.utils.Dictionary;
            if(!cache)
            {
               cache = new flash.utils.Dictionary(true);
               s_deepPaletteCaches[root] = cache;
            }
         }
         replacePaletteDeepWalk(root,paletteData,recursion,cache,smoothing,rgbOnly);
      }

      public static function replacePaletteDeepWalk(node:DisplayObject, paletteData:Object, depth:int, cache:flash.utils.Dictionary, smoothing:Boolean, rgbOnly:Boolean = false) : void
      {
         var bmp:Bitmap = null;
         var bd:BitmapData = null;
         var container:DisplayObjectContainer = null;
         var i:int = 0;
         if(!node || depth < 0)
         {
            return;
         }
         if(node is Bitmap)
         {
            bmp = node as Bitmap;
            if(bmp.name == "_unchangedOutline")
            {
               return;
            }
            bd = bmp.bitmapData;
            if(!isUsableBitmapData(bd))
            {
               return;
            }
            if(!s_pristineBitmaps[bmp])
            {
               s_pristineBitmaps[bmp] = bd.clone();
            }
            bd = (s_pristineBitmaps[bmp] as BitmapData).clone();
            if(Boolean(paletteData))
            {
               replacePaletteHelper(bd,paletteData,rgbOnly);
            }
            bmp.bitmapData = bd;
            bmp.smoothing = smoothing;
            return;
         }
         if(node is Shape)
         {
            replacePaletteShapeGraphics(node,paletteData,cache != null,rgbOnly);
            return;
         }
         container = node as DisplayObjectContainer;
         if(!container)
         {
            return;
         }
         replacePaletteShapeGraphics(container,paletteData,cache != null,rgbOnly);
         i = 0;
         while(i < container.numChildren)
         {
            replacePaletteDeepWalk(container.getChildAt(i),paletteData,depth - 1,cache,smoothing,rgbOnly);
            i++;
         }
      }

      public static function replacePaletteShapeGraphics(obj:DisplayObject, paletteData:Object, cacheOriginal:Boolean, rgbOnly:Boolean = false) : void
      {
         var g:Graphics = null;
         var src:Vector.<IGraphicsData> = null;
         var painted:Vector.<IGraphicsData> = null;
         if(!obj || !paletteData)
         {
            return;
         }
         if(obj is Shape)
         {
            g = (obj as Shape).graphics;
         }
         else if(obj is Sprite)
         {
            g = (obj as Sprite).graphics;
         }
         else
         {
            return;
         }
         if(!g)
         {
            return;
         }
         if(cacheOriginal)
         {
            src = s_shapeGraphicsCaches[obj] as Vector.<IGraphicsData>;
         }
         if(!src)
         {
            try
            {
               src = g.readGraphicsData(false);
            }
            catch(readErr:Error)
            {
               src = null;
            }
            if(cacheOriginal && src && src.length > 0)
            {
               s_shapeGraphicsCaches[obj] = src;
            }
         }
         if(!src || src.length == 0)
         {
            return;
         }
         painted = remapGraphicsData(src,paletteData,rgbOnly,cacheOriginal);
         if(!painted || painted.length == 0)
         {
            return;
         }
         try
         {
            g.clear();
            g.drawGraphicsData(painted);
         }
         catch(drawErr:Error)
         {
         }
      }

      public static function remapGraphicsData(src:Vector.<IGraphicsData>, paletteData:Object, rgbOnly:Boolean, cacheOriginal:Boolean = false) : Vector.<IGraphicsData>
      {
         var out:Vector.<IGraphicsData> = null;
         var map:Object = null;
         var i:int = 0;
         var item:IGraphicsData = null;
         out = new Vector.<IGraphicsData>();
         if(!src)
         {
            return out;
         }
         map = buildShapeColorMap(paletteData,rgbOnly);
         i = 0;
         while(i < src.length)
         {
            item = src[i];
            out.push(remapGraphicsItem(item,map,paletteData,rgbOnly,cacheOriginal));
            i++;
         }
         return out;
      }

      public static function buildShapeColorMap(paletteData:Object, rgbOnly:Boolean) : Object
      {
         var map:Object = null;
         var colors:Array = null;
         var repls:Array = null;
         var i:int = 0;
         var src:uint = 0;
         var repl:uint = 0;
         map = {};
         if(!paletteData || !(paletteData.colors is Array) || !(paletteData.replacements is Array))
         {
            return map;
         }
         colors = paletteData.colors as Array;
         repls = paletteData.replacements as Array;
         i = 0;
         while(i < colors.length && i < repls.length)
         {
            src = uint(colors[i]);
            repl = uint(repls[i]);
            if(src != repl)
            {
               if(!rgbOnly && ((src & 0xFFFFFF) == (repl & 0xFFFFFF) && (repl >> 24 & 0xFF) == 0))
               {
                  i++;
                  continue;
               }
               map[String(src)] = repl;
               map[String(src & 0xFFFFFF)] = repl;
            }
            i++;
         }
         return map;
      }

      public static function lookupShapeRepl(map:Object, color:uint) : *
      {
         var key:String = null;
         if(!map)
         {
            return null;
         }
         key = String(color);
         if(map.hasOwnProperty(key))
         {
            return map[key];
         }
         key = String(color & 0xFFFFFF);
         if(map.hasOwnProperty(key))
         {
            return map[key];
         }
         key = String(uint(color | 0xFF000000));
         if(map.hasOwnProperty(key))
         {
            return map[key];
         }
         return null;
      }

      public static function remapGraphicsItem(item:IGraphicsData, map:Object, paletteData:Object, rgbOnly:Boolean, cacheOriginal:Boolean = false) : IGraphicsData
      {
         var solid:GraphicsSolidFill = null;
         var grad:GraphicsGradientFill = null;
         var bmpFill:GraphicsBitmapFill = null;
         var stroke:GraphicsStroke = null;
         var found:* = undefined;
         var colors:Array = null;
         var i:int = 0;
         var next:uint = 0;
         if(item is GraphicsSolidFill)
         {
            solid = item as GraphicsSolidFill;
            found = lookupShapeRepl(map,uint(solid.color));
            if(found == null)
            {
               return item;
            }
            next = uint(found);
            return new GraphicsSolidFill(next & 0xFFFFFF,(next >> 24 & 0xFF) == 255 ? solid.alpha : (next >> 24 & 0xFF) / 255);
         }
         if(item is GraphicsGradientFill)
         {
            grad = item as GraphicsGradientFill;
            colors = [];
            i = 0;
            while(i < grad.colors.length)
            {
               found = lookupShapeRepl(map,uint(grad.colors[i]));
               if(found == null)
               {
                  colors.push(grad.colors[i]);
               }
               else
               {
                  colors.push(uint(found) & 0xFFFFFF);
               }
               i++;
            }
            return new GraphicsGradientFill(grad.type,colors,grad.alphas,grad.ratios,grad.matrix,grad.spreadMethod,grad.interpolationMethod,grad.focalPointRatio);
         }
         if(item is GraphicsBitmapFill)
         {
            bmpFill = item as GraphicsBitmapFill;
            paintCachedBitmapFill(bmpFill.bitmapData,paletteData,rgbOnly,cacheOriginal);
            return item;
         }
         if(item is GraphicsStroke)
         {
            stroke = item as GraphicsStroke;
            return new GraphicsStroke(stroke.thickness,stroke.pixelHinting,stroke.scaleMode,stroke.caps,stroke.joints,stroke.miterLimit,remapGraphicsFill(stroke.fill,map,paletteData,rgbOnly,cacheOriginal) as IGraphicsFill);
         }
         return item;
      }

      public static function remapGraphicsFill(fill:IGraphicsFill, map:Object, paletteData:Object, rgbOnly:Boolean, cacheOriginal:Boolean = false) : IGraphicsFill
      {
         var item:IGraphicsData = null;
         if(!fill)
         {
            return fill;
         }
         if(fill is IGraphicsData)
         {
            item = remapGraphicsItem(fill as IGraphicsData,map,paletteData,rgbOnly,cacheOriginal);
            if(item is IGraphicsFill)
            {
               return item as IGraphicsFill;
            }
         }
         return fill;
      }

      public static function paintCachedBitmapFill(bd:BitmapData, paletteData:Object, rgbOnly:Boolean, cacheOriginal:Boolean) : void
      {
         var original:BitmapData = null;
         if(!bd || !paletteData || !isUsableBitmapData(bd))
         {
            return;
         }
         if(cacheOriginal)
         {
            original = s_shapeBitmapOriginals[bd] as BitmapData;
            if(!original)
            {
               try
               {
                  original = bd.clone();
                  s_shapeBitmapOriginals[bd] = original;
               }
               catch(cloneErr:Error)
               {
                  original = null;
               }
            }
            else if(isUsableBitmapData(original))
            {
               try
               {
                  bd.lock();
                  bd.fillRect(bd.rect,0);
                  bd.draw(original);
                  bd.unlock();
               }
               catch(restoreErr:Error)
               {
               }
            }
         }
         replacePaletteHelper(bd,paletteData,rgbOnly);
      }

      public static function isUsableBitmapData(bd:BitmapData) : Boolean
      {
         if(!bd)
         {
            return false;
         }
         try
         {
            if(bd.width <= 0 || bd.height <= 0)
            {
               return false;
            }
         }
         catch(err:Error)
         {
            return false;
         }
         return true;
      }

      public static function replacePaletteHelper(bitmapData:BitmapData, paletteData:Object, rgbOnly:Boolean = false) : void
      {
         var _loc4_:int = 0;
         var _loc5_:* = undefined;
         var i:int = 0;
         var colors:Array = null;
         var repls:Array = null;
         var map:Object = null;
         var pixels:Vector.<uint> = null;
         var n:int = 0;
         var pix:uint = 0;
         var rgb:uint = 0;
         var key:String = null;
         var repl:uint = 0;
         var srcA:uint = 0;
         var replA:uint = 0;
         var outA:uint = 0;
         var source:BitmapData = null;
         var replByKey:Object = null;
         var hasRepl:Boolean = false;
         if(!bitmapData || !paletteData || !(paletteData.colors is Array) || !(paletteData.replacements is Array))
         {
            return;
         }
         if(!isUsableBitmapData(bitmapData))
         {
            return;
         }
         colors = paletteData.colors as Array;
         repls = paletteData.replacements as Array;
         if(!rgbOnly)
         {
            paletteRect.width = bitmapData.width;
            paletteRect.height = bitmapData.height;
            source = null;
            replByKey = {};
            i = 0;
            while(i < colors.length && i < repls.length)
            {
               if(colors[i] != repls[i])
               {
                  if((uint(colors[i]) & 0xFFFFFF) == (uint(repls[i]) & 0xFFFFFF) && (uint(repls[i]) >> 24 & 0xFF) == 0)
                  {
                     i++;
                     continue;
                  }
                  replByKey[String(uint(colors[i]))] = {
                     "c":uint(colors[i]),
                     "r":uint(repls[i])
                  };
               }
               i++;
            }
            hasRepl = false;
            _loc4_ = 0;
            _loc5_ = replByKey;
            for(key in _loc5_)
            {
               hasRepl = true;
            }
            if(!hasRepl)
            {
               return;
            }
            for(key in replByKey)
            {
               if(!source)
               {
                  source = bitmapData.clone();
               }
               bitmapData.threshold(source,paletteRect,palettePoint,"==",uint(replByKey[key].c),uint(replByKey[key].r),uint(4294967295),false);
            }
            if(Boolean(source))
            {
               source.dispose();
            }
            return;
         }
         map = {};
         i = 0;
         while(i < colors.length && i < repls.length)
         {
            if(colors[i] != repls[i])
            {
               key = String(uint(colors[i]) & 0xFFFFFF);
               if(!map.hasOwnProperty(key))
               {
                  map[key] = uint(repls[i]);
               }
            }
            i++;
         }
         pixels = bitmapData.getVector(bitmapData.rect);
         n = int(pixels.length);
         i = 0;
         while(i < n)
         {
            pix = pixels[i];
            srcA = uint(pix >> 24 & 0xFF);
            if(srcA != 0)
            {
               rgb = uint(pix & 0xFFFFFF);
               key = String(rgb);
               if(map.hasOwnProperty(key))
               {
                  repl = uint(map[key]);
                  replA = uint(repl >> 24 & 0xFF);
                  outA = srcA * replA / 255;
                  pixels[i] = outA << 24 | repl & 0xFFFFFF;
               }
            }
            i++;
         }
         bitmapData.setVector(bitmapData.rect,pixels);
      }

      public static function removeActionScript(target:MovieClip) : void
      {
         var i:int = 0;
         while(i < target.totalFrames)
         {
            target.addFrameScript(i,null);
            i++;
         }
      }

      public static function removeActionScriptDeep(target:MovieClip, recursion:int = 8) : void
      {
         var i:int = 0;
         var child:DisplayObject = null;
         if(!target || recursion < 0)
         {
            return;
         }
         try
         {
            removeActionScript(target);
            target.stop();
         }
         catch(err:Error)
         {
         }
         i = 0;
         while(i < target.numChildren)
         {
            child = target.getChildAt(i);
            if(child is MovieClip)
            {
               removeActionScriptDeep(child as MovieClip,recursion - 1);
            }
            i++;
         }
      }

      public static function isFragileTimelineClip(mc:*) : Boolean
      {
         var qn:String = null;
         var nm:String = null;
         var clip:MovieClip = null;
         if(!(mc is MovieClip))
         {
            return false;
         }
         clip = mc as MovieClip;
         mc = clip;
         if(!mc)
         {
            return false;
         }
         try
         {
            qn = getQualifiedClassName(mc);
            if(Boolean(qn) && qn.indexOf("finalExplosion") >= 0)
            {
               return true;
            }
         }
         catch(qnErr:*)
         {
         }
         try
         {
            nm = mc.name;
            if(Boolean(nm) && nm.indexOf("finalExplosion") >= 0)
            {
               return true;
            }
         }
         catch(nmErr:*)
         {
         }
         return false;
      }

      public static function advanceEffectFrame(mc:MovieClip) : void
      {
         if(!mc)
         {
            return;
         }
         if(Boolean(mc.bypassTicker))
         {
            return;
         }
         if(mc.currentFrame == mc.totalFrames && mc.totalFrames > 1)
         {
            mc.stop();
            if(Boolean(mc.parent))
            {
               mc.parent.removeChild(mc);
            }
            return;
         }
         try
         {
            mc.nextFrame();
         }
         catch(e:*)
         {
         }
         mc.stop();
      }

   }
}
