package com.mcleodgaming.ssf2.util
{
   import flash.display.*;
   import flash.events.*;
   import flash.geom.*;
   import flash.utils.ByteArray;
   import ssf2mm.shared.SvgPath;
   import ssf2mm.shared.EngineRefs;
   
   public class VectorIconSvg
   {
      
      public function VectorIconSvg()
      {
         super();
      }
      
      /** The expansion_loader.vectorIcon door: op is hasVisibleContent, hasEmbeddedImage, toMovieClip, captureIcon or decodeFirstImage. */
      public static function dispatch(op:String, a:* = null, b:* = null) : *
      {
         if(op == "hasVisibleContent")
         {
            return hasVisibleContent(a);
         }
         if(op == "hasEmbeddedImage")
         {
            return hasEmbeddedImage(a);
         }
         if(op == "toMovieClip")
         {
            return toMovieClip(a);
         }
         if(op == "captureIcon")
         {
            return captureIcon(a);
         }
         if(op == "decodeFirstImage")
         {
            decodeFirstImage(a,b);
         }
         return null;
      }
            public static function fromDisplayObject(root:DisplayObject) : String
      {
         var captured:Object = captureIcon(root);
         return Boolean(captured) ? captured.svg : null;
      }
      
      public static function captureIcon(root:DisplayObject) : Object
      {
         var bounds:Rectangle = null;
         var parts:Array = null;
         var blit:Object = null;
         if(!root)
         {
            return null;
         }
         try
         {
            bounds = root.getBounds(root);
         }
         catch(bErr:*)
         {
            bounds = new Rectangle(0,0,16,16);
         }
         if(bounds.width <= 0 || bounds.height <= 0)
         {
            bounds.width = Math.max(1,bounds.width);
            bounds.height = Math.max(1,bounds.height);
         }
         parts = [];
         walk(root,new Matrix(),parts);
         if(parts.length > 0)
         {
            return {
               "svg":wrapSvg(bounds,parts.join("")),
               "blit":null
            };
         }
         blit = makeBlit(root,bounds);
         if(!blit)
         {
            return null;
         }
         return {
            "svg":blitSvg(blit),
            "blit":blit
         };
      }
      
      public static function hasVisibleContent(svg:String) : Boolean
      {
         if(!svg)
         {
            return false;
         }
         if(svg.indexOf("<image") >= 0)
         {
            return true;
         }
         if(svg.indexOf("fill=\"#") >= 0)
         {
            return true;
         }
         if(svg.indexOf("fill=\'#") >= 0)
         {
            return true;
         }
         return false;
      }
      
      public static function hasEmbeddedImage(svg:String) : Boolean
      {
         return Boolean(svg) && svg.indexOf("<image") >= 0;
      }
      
      public static function decodeFirstImage(svg:String, onDone:Function) : void
      {
         var loader:Loader = null;
         var imgX:Number = NaN;
         var imgY:Number = NaN;
         var tagMatch:Array = null;
         var tag:String = null;
         var href:String = null;
         var b64:String = null;
         var bytes:ByteArray = null;
         var onLoaded:Function = null;
         var onFailed:Function = null;
         var release:Function = null;
         if(onDone == null)
         {
            return;
         }
         if(!hasEmbeddedImage(svg))
         {
            onDone(null);
            return;
         }
         tagMatch = svg.match(/<image\s+([^>]+)>/);
         if(!tagMatch || tagMatch.length < 2)
         {
            onDone(null);
            return;
         }
         tag = String(tagMatch[1]);
         href = xmlAttr(tag,"href");
         if(!href)
         {
            href = xmlAttr(tag,"xlink:href");
         }
         if(href.indexOf("base64,") >= 0)
         {
            b64 = href.substr(href.indexOf("base64,") + 7);
         }
         else
         {
            b64 = href;
         }
         b64 = b64.replace(/\s+/g,"");
         if(!b64)
         {
            onDone(null);
            return;
         }
         imgX = Number(xmlAttr(tag,"x") || 0);
         imgY = Number(xmlAttr(tag,"y") || 0);
         if(isNaN(imgX))
         {
            imgX = 0;
         }
         if(isNaN(imgY))
         {
            imgY = 0;
         }
         try
         {
            bytes = EngineRefs.cls("com.hurlant.util.Base64")["decodeToByteArray"](b64);
            loader = new Loader();
            release = function():void
            {
               loader.contentLoaderInfo.removeEventListener(Event.COMPLETE,onLoaded);
               loader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR,onFailed);
               try
               {
                  loader.unload();
               }
               catch(unloadErr:*)
               {
               }
            };
            onLoaded = function(e:Event):void
            {
               var bmp:Bitmap = null;
               var result:Object = null;
               try
               {
                  bmp = loader.content as Bitmap;
                  if(Boolean(bmp) && Boolean(bmp.bitmapData))
                  {
                     result = {
                        "bd":bmp.bitmapData.clone(),
                        "x":imgX,
                        "y":imgY
                     };
                  }
               }
               catch(okErr:*)
               {
               }
               release();
               onDone(result);
            };
            onFailed = function(e:IOErrorEvent):void
            {
               release();
               onDone(null);
            };
            loader.contentLoaderInfo.addEventListener(Event.COMPLETE,onLoaded);
            loader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR,onFailed);
            loader.loadBytes(bytes);
         }
         catch(decErr:*)
         {
            onDone(null);
         }
      }
      
      public static function toMovieClip(svg:String) : MovieClip
      {
         var wrap:MovieClip = null;
         wrap = null;
         wrap = null;
         wrap = null;
         wrap = null;
         var xml:XML = null;
         wrap = new MovieClip();
         if(!svg)
         {
            return wrap;
         }
         try
         {
            xml = new XML(svg);
         }
         catch(xmlErr:*)
         {
            return wrap;
         }
         drawNode(wrap.graphics,xml,new Matrix());
         wrap.graphics.endFill();
         wrap.x = 0;
         wrap.y = 0;
         return wrap;
      }
      
      private static function walk(obj:DisplayObject, toLocal:Matrix, parts:Array) : void
      {
         var g:Graphics = null;
         var i:int = 0;
         var child:DisplayObject = null;
         var childMatrix:Matrix = null;
         var box:DisplayObjectContainer = null;
         if(!obj || !obj.visible || obj.alpha <= 0)
         {
            return;
         }
         g = graphicsOf(obj);
         if(Boolean(g))
         {
            appendGraphics(g,toLocal,parts);
         }
         box = obj as DisplayObjectContainer;
         if(!box)
         {
            return;
         }
         i = 0;
         while(i < box.numChildren)
         {
            child = box.getChildAt(i);
            if(Boolean(child))
            {
               childMatrix = toLocal.clone();
               try
               {
                  childMatrix.concat(child.transform.matrix);
               }
               catch(mErr:*)
               {
               }
               walk(child,childMatrix,parts);
            }
            i++;
         }
      }
      
      private static function graphicsOf(obj:DisplayObject) : Graphics
      {
         if(obj is Shape)
         {
            return (obj as Shape).graphics;
         }
         if(obj is Sprite)
         {
            return (obj as Sprite).graphics;
         }
         return null;
      }
      
      private static function appendGraphics(g:Graphics, m:Matrix, parts:Array) : void
      {
         var data:Vector.<IGraphicsData> = null;
         var i:int = 0;
         var item:IGraphicsData = null;
         var fill:GraphicsSolidFill = null;
         var stroke:GraphicsStroke = null;
         var strokeFill:GraphicsSolidFill = null;
         var path:GraphicsPath = null;
         var d:String = null;
         try
         {
            data = g.readGraphicsData(false);
         }
         catch(readErr:*)
         {
            return;
         }
         if(!data || data.length == 0)
         {
            return;
         }
         d = "";
         i = 0;
         while(i < data.length)
         {
            item = data[i];
            if(item is GraphicsSolidFill)
            {
               flushPath(parts,d,fill,stroke,strokeFill,m);
               d = "";
               fill = item as GraphicsSolidFill;
               stroke = null;
               strokeFill = null;
            }
            else if(item is GraphicsGradientFill)
            {
               flushPath(parts,d,fill,stroke,strokeFill,m);
               d = "";
               fill = new GraphicsSolidFill((item as GraphicsGradientFill).colors[0],(item as GraphicsGradientFill).alphas[0]);
               stroke = null;
               strokeFill = null;
            }
            else if(item is GraphicsStroke)
            {
               stroke = item as GraphicsStroke;
               strokeFill = stroke.fill is GraphicsSolidFill ? stroke.fill as GraphicsSolidFill : null;
            }
            else if(item is GraphicsPath)
            {
               path = item as GraphicsPath;
               d += pathToD(path,m);
            }
            else if(item is GraphicsEndFill)
            {
               flushPath(parts,d,fill,stroke,strokeFill,m);
               d = "";
               fill = null;
            }
            i++;
         }
         flushPath(parts,d,fill,stroke,strokeFill,m);
      }
      
      private static function wrapSvg(bounds:Rectangle, body:String) : String
      {
         return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"" + num(bounds.x) + " " + num(bounds.y) + " " + num(bounds.width) + " " + num(bounds.height) + "\">" + body + "</svg>";
      }
      
      private static function makeBlit(root:DisplayObject, bounds:Rectangle) : Object
      {
         var w:int = 0;
         var h:int = 0;
         var bd:BitmapData = null;
         var m:Matrix = null;
         if(!root || !bounds)
         {
            return null;
         }
         w = Math.max(1,Math.ceil(bounds.width));
         h = Math.max(1,Math.ceil(bounds.height));
         try
         {
            bd = new BitmapData(w,h,true,0);
            m = new Matrix();
            m.translate(-bounds.x,-bounds.y);
            bd.draw(root,m,null,null,null,true);
         }
         catch(drawErr:*)
         {
            return null;
         }
         return {
            "bd":bd,
            "x":bounds.x,
            "y":bounds.y
         };
      }
      
      private static function blitSvg(blit:Object) : String
      {
         var bd:BitmapData = null;
         var bytes:ByteArray = null;
         var b64:String = null;
         var x:Number = NaN;
         var y:Number = NaN;
         if(!blit)
         {
            return null;
         }
         bd = blit.bd as BitmapData;
         if(!bd)
         {
            return null;
         }
         x = Number(blit.x || 0);
         y = Number(blit.y || 0);
         try
         {
            bytes = EngineRefs.cls("com.adobe.images.PNGEncoder")["encode"](bd);
            b64 = EngineRefs.cls("com.hurlant.util.Base64")["encodeByteArray"](bytes);
         }
         catch(encErr:*)
         {
            return null;
         }
         return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"" + num(x) + " " + num(y) + " " + num(bd.width) + " " + num(bd.height) + "\"><image x=\"" + num(x) + "\" y=\"" + num(y) + "\" width=\"" + num(bd.width) + "\" height=\"" + num(bd.height) + "\" href=\"data:image/png;base64," + b64 + "\"/></svg>";
      }
      
      private static function xmlAttr(tag:String, name:String) : String
      {
         var matched:Array = null;
         if(!tag || !name)
         {
            return "";
         }
         matched = tag.match(new RegExp(name + "=\"([^\"]+)\""));
         if(Boolean(matched) && matched.length > 1)
         {
            return String(matched[1]);
         }
         return "";
      }
      
      private static function flushPath(parts:Array, d:String, fill:GraphicsSolidFill, stroke:GraphicsStroke, strokeFill:GraphicsSolidFill, m:Matrix) : void
      {
         var attrs:String = null;
         var hasFill:Boolean = false;
         var hasStroke:Boolean = false;
         if(!d || d.length == 0)
         {
            return;
         }
         hasFill = Boolean(fill) && fill.alpha > 0.001;
         hasStroke = stroke && strokeFill && stroke.thickness > 0 && strokeFill.alpha > 0.001;
         if(!hasFill && !hasStroke)
         {
            return;
         }
         attrs = " d=\"" + d + "\"";
         if(Boolean(fill))
         {
            attrs += " fill=\"" + colorCss(fill.color) + "\"";
            if(fill.alpha < 0.999)
            {
               attrs += " fill-opacity=\"" + num(fill.alpha) + "\"";
            }
         }
         else
         {
            attrs += " fill=\"none\"";
         }
         if(Boolean(stroke) && Boolean(strokeFill) && stroke.thickness > 0)
         {
            attrs += " stroke=\"" + colorCss(strokeFill.color) + "\"";
            attrs += " stroke-width=\"" + num(stroke.thickness) + "\"";
            if(strokeFill.alpha < 0.999)
            {
               attrs += " stroke-opacity=\"" + num(strokeFill.alpha) + "\"";
            }
         }
         else
         {
            attrs += " stroke=\"none\"";
         }
         parts.push("<path" + attrs + "/>");
      }
      
      private static function pathToD(path:GraphicsPath, m:Matrix) : String
      {
         var out:String = null;
         var cmds:Vector.<int> = null;
         var data:Vector.<Number> = null;
         var ci:int = 0;
         var di:int = 0;
         var cmd:int = 0;
         var p:Point = null;
         out = "";
         if(!path || !path.commands || !path.data)
         {
            return out;
         }
         cmds = path.commands;
         data = path.data;
         ci = 0;
         di = 0;
         while(ci < cmds.length)
         {
            cmd = cmds[ci];
            if(cmd == GraphicsPathCommand.MOVE_TO)
            {
               p = xf(data[di],data[di + 1],m);
               out += " M " + num(p.x) + (" " + num(p.y));
               di += 2;
            }
            else if(cmd == GraphicsPathCommand.LINE_TO)
            {
               p = xf(data[di],data[di + 1],m);
               out += " L " + num(p.x) + (" " + num(p.y));
               di += 2;
            }
            else if(cmd == GraphicsPathCommand.CURVE_TO)
            {
               p = xf(data[di],data[di + 1],m);
               out += " Q " + num(p.x) + (" " + num(p.y));
               p = xf(data[di + 2],data[di + 3],m);
               out += " " + num(p.x) + (" " + num(p.y));
               di += 4;
            }
            else if(cmd == GraphicsPathCommand.CUBIC_CURVE_TO)
            {
               p = xf(data[di],data[di + 1],m);
               out += " C " + num(p.x) + (" " + num(p.y));
               p = xf(data[di + 2],data[di + 3],m);
               out += " " + num(p.x) + (" " + num(p.y));
               p = xf(data[di + 4],data[di + 5],m);
               out += " " + num(p.x) + (" " + num(p.y));
               di += 6;
            }
            else if(cmd == GraphicsPathCommand.WIDE_MOVE_TO || cmd == GraphicsPathCommand.WIDE_LINE_TO)
            {
               p = xf(data[di + 2],data[di + 3],m);
               out += (cmd == GraphicsPathCommand.WIDE_MOVE_TO ? " M " : " L ") + num(p.x) + (" " + num(p.y));
               di += 4;
            }
            ci++;
         }
         return out;
      }
      
      private static function drawNode(g:Graphics, node:XML, m:Matrix) : void
      {
         var child:XML = null;
         var localName:String = null;
         var childMatrix:Matrix = null;
         if(!node)
         {
            return;
         }
         localName = String(node.localName() || "");
         if(localName == "path")
         {
            drawPath(g,node,m);
         }
         for each(child in node.children())
         {
            childMatrix = m.clone();
            if(child.@transform != undefined)
            {
               childMatrix.concat(parseMatrix(String(child.@transform)));
            }
            drawNode(g,child,childMatrix);
         }
      }
      
      private static function drawPath(g:Graphics, node:XML, m:Matrix) : void
      {
         var fill:String = null;
         var stroke:String = null;
         var fillColor:uint = 0;
         var strokeColor:uint = 0;
         var fillAlpha:Number = NaN;
         var strokeWidth:Number = NaN;
         fill = String(node.@fill || "none");
         stroke = String(node.@stroke || "none");
         fillAlpha = node["fill-opacity"] != undefined ? Number(node["fill-opacity"]) : 1;
         strokeWidth = node["stroke-width"] != undefined ? Number(node["stroke-width"]) : 1;
         if(fill != "none" && Boolean(fill))
         {
            fillColor = uint(parseColor(fill));
            g.beginFill(fillColor,isNaN(fillAlpha) ? 1 : fillAlpha);
         }
         if(stroke != "none" && Boolean(stroke))
         {
            strokeColor = uint(parseColor(stroke));
            g.lineStyle(strokeWidth,strokeColor,1,false,"normal","round","round");
         }
         else
         {
            g.lineStyle();
         }
         SvgPath.draw(g,String(node.@d || ""),m);
         if(fill != "none" && Boolean(fill))
         {
            g.endFill();
         }
      }
      
      private static function parseMatrix(value:String) : Matrix
      {
         var m:Matrix = null;
         var inner:String = null;
         var n:Array = null;
         m = new Matrix();
         if(!value)
         {
            return m;
         }
         if(value.indexOf("matrix(") == 0)
         {
            inner = value.substring(7,value.indexOf(")"));
            n = inner.split(/[,\s]+/);
            m.a = Number(n[0] || 1);
            m.b = Number(n[1] || 0);
            m.c = Number(n[2] || 0);
            m.d = Number(n[3] || 1);
            m.tx = Number(n[4] || 0);
            m.ty = Number(n[5] || 0);
         }
         return m;
      }
      
      private static function parseColor(value:String) : uint
      {
         if(Boolean(value) && value.charAt(0) == "#")
         {
            return uint("0x" + value.substr(1));
         }
         return 0;
      }
      
      private static function xf(x:Number, y:Number, m:Matrix) : Point
      {
         if(!m)
         {
            return new Point(x,y);
         }
         return m.transformPoint(new Point(x,y));
      }
      
      private static function colorCss(color:uint) : String
      {
         var hex:String = color.toString(16);
         while(hex.length < 6)
         {
            hex = "0" + hex;
         }
         return "#" + hex;
      }
      
      private static function num(value:Number) : String
      {
         if(isNaN(value))
         {
            return "0";
         }
         return String(Math.round(value * 1000) / 1000);
      }
   }
}

