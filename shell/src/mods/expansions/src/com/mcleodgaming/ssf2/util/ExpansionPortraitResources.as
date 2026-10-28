package com.mcleodgaming.ssf2.util
{
   import com.mcleodgaming.ssf2.*;
   import com.mcleodgaming.ssf2.api.*;
   import com.mcleodgaming.ssf2.controllers.*;
   import com.mcleodgaming.ssf2.engine.*;
   import com.mcleodgaming.ssf2.modhost.*;
   import flash.display.*;
   import flash.events.*;
   import flash.filesystem.*;
   import flash.media.*;
   import flash.system.*;
   import flash.utils.ByteArray;
   import ssf2mm.shared.EngineRefs;

   public class ExpansionPortraitResources
   {
      private static const TRACE_UI_LINKS:Boolean = false;

      public static function getExpansionStockBitmapData(statsName:String) : BitmapData
      {
         if(Boolean(statsName) && Boolean(ResourceManager.m_expansionStockBitmapData[statsName]))
         {
            return ResourceManager.m_expansionStockBitmapData[statsName] as BitmapData;
         }
         return null;
      }

      public static function getExpansionPABitmapData(statsName:String) : BitmapData
      {
         if(Boolean(statsName) && Boolean(ResourceManager.m_expansionPABitmapData[statsName]))
         {
            return ResourceManager.m_expansionPABitmapData[statsName] as BitmapData;
         }
         return null;
      }

      public static function getExpansionStockMC(statsName:String) : MovieClip
      {
         var donorClip:MovieClip = ExpansionLibraryResources.donorLibraryMC(statsName,"_stock");
         if(Boolean(donorClip))
         {
            return donorClip;
         }
         var bd:BitmapData = getExpansionStockBitmapData(statsName);
         if(!bd)
         {
            return null;
         }
         return wrapStockBitmapData(bd);
      }

      public static function wrapStockBitmapData(bd:BitmapData) : MovieClip
      {
         var ref:MovieClip = null;
         var tw:Number = NaN;
         var th:Number = NaN;
         if(!bd)
         {
            return null;
         }
         ref = ResourceManager.getLibraryMC("random_stock");
         tw = Boolean(ref) && ref.width > 0 ? ref.width : Number(ResourceManager.FALLBACK_STOCK_SIZE);
         th = Boolean(ref) && ref.height > 0 ? ref.height : Number(ResourceManager.FALLBACK_STOCK_SIZE);
         return bitmapDataToFittedMC(bd,tw,th,ResourceManager.ALIGN_CENTER);
      }

      public static function tryRealExpansionFolderStockMC(statsName:String) : MovieClip
      {
         var folder:File = null;
         if(Boolean(ExpansionLibraryResources.oldAssetId(statsName)))
         {
            return null;
         }
         var stockFile:File = null;
         if(!statsName)
         {
            return null;
         }
         if(Boolean(getExpansionStockBitmapData(statsName)))
         {
            return getExpansionStockMC(statsName);
         }
         try
         {
            folder = File.applicationDirectory.resolvePath("expansions/character/" + statsName);
            if(!folder || !folder.exists || !folder.isDirectory)
            {
               return null;
            }
            if(!folder.resolvePath("assets.swf").exists)
            {
               return null;
            }
            stockFile = folder.resolvePath("stock.png");
            if(!stockFile.exists)
            {
               return null;
            }
            ExpansionCharacterPacks.loadExpansionPng(statsName,stockFile,false);
            if(shouldTraceUiLink(statsName))
            {
               GameLog.write("[ResourceManager] real expansion stock.png -> " + statsName);
            }
         }
         catch(err:*)
         {
            return null;
         }
         return getExpansionStockMC(statsName);
      }

      public static function tryInstantiateRealExpansionAssets(statsName:String, suffix:String) : MovieClip
      {
         var uiId:String = null;
         if(Boolean(ExpansionLibraryResources.oldAssetId(statsName)))
         {
            return null;
         }
         var res:Resource = null;
         var mc:MovieClip = null;
         if(!statsName || !suffix)
         {
            return null;
         }
         uiId = "ui_tpl_" + statsName;
         res = ResourceManager.getResourceByID(uiId,true);
         if(!res)
         {
            return null;
         }
         mc = ModHost.instantiateFromResource(uiId,suffix);
         if(Boolean(mc))
         {
            return mc;
         }
         return ModHost.instantiateFromResource(uiId,statsName + "_" + suffix);
      }

      public static function wrapClassicPortraitMC(art:MovieClip, statsName:String = null) : MovieClip
      {
         var root:MovieClip = null;
         var pa:MovieClip = null;
         var child:DisplayObject = null;
         var yNudge:Number = getClassicPaYNudge(statsName);
         if(!art)
         {
            return null;
         }
         if(Boolean(art.getChildByName("PA")))
         {
            return art;
         }
         root = new MovieClip();
         pa = new MovieClip();
         pa.name = "PA";
         while(art.numChildren > 0)
         {
            child = art.removeChildAt(0);
            child.x += art.x;
            child.y = child.y + art.y + yNudge;
            pa.addChild(child);
         }
         root.addChild(pa);
         return root;
      }

      public static function getExpansionPortraitMC(statsName:String, vAlign:String = null) : MovieClip
      {
         var donorClip:MovieClip = ExpansionLibraryResources.donorLibraryMC(statsName,"_classic");
         if(!donorClip)
         {
            donorClip = ExpansionLibraryResources.donorLibraryMC(statsName,"_classic_trophy");
         }
         if(Boolean(donorClip))
         {
            return donorClip;
         }
         var ref:MovieClip = null;
         var tw:Number = NaN;
         var th:Number = NaN;
         var bd:BitmapData = getExpansionPABitmapData(statsName);
         if(!bd)
         {
            return null;
         }
         ref = ResourceManager.getLibraryMC("mario_classic_trophy");
         if(!ref)
         {
            ref = ResourceManager.getLibraryMC("mario_charselect");
         }
         if(!ref)
         {
            ref = ResourceManager.getLibraryMC("rand_mc");
         }
         tw = Boolean(ref) && ref.width > 0 ? ref.width : Number(ResourceManager.FALLBACK_PA_SIZE);
         th = Boolean(ref) && ref.height > 0 ? ref.height : Number(ResourceManager.FALLBACK_PA_SIZE);
         return bitmapDataToFittedMC(bd,tw,th,vAlign || ResourceManager.ALIGN_CENTER);
      }

      public static function getExpansionCharSelectMC(statsName:String) : MovieClip
      {
         var donorClip:MovieClip = ExpansionLibraryResources.donorLibraryMC(statsName,"_charselect");
         if(Boolean(donorClip))
         {
            return donorClip;
         }
         var ref:MovieClip = null;
         var tw:Number = NaN;
         var th:Number = NaN;
         var mc:MovieClip = null;
         var bd:BitmapData = getExpansionPABitmapData(statsName);
         if(!bd)
         {
            return null;
         }
         ref = ResourceManager.getLibraryMC("mario_charselect");
         if(!ref)
         {
            ref = ResourceManager.getLibraryMC("rand_mc");
         }
         if(!ref)
         {
            ref = ResourceManager.getLibraryMC("mario_classic_trophy");
         }
         tw = Boolean(ref) && ref.width > 0 ? ref.width : Number(ResourceManager.FALLBACK_PA_SIZE);
         th = Boolean(ref) && ref.height > 0 ? ref.height : Number(ResourceManager.FALLBACK_PA_SIZE);
         mc = bitmapDataToFittedMC(bd,tw,th,ResourceManager.ALIGN_CENTER);
         if(Boolean(mc))
         {
            mc.y = getCssPaYNudge(statsName);
         }
         return mc;
      }

      public static function getCssPaYNudge(statsName:String) : Number
      {
         if(Boolean(statsName) && Boolean(ResourceManager.m_expansionCssPaYNudge[statsName] != null) && !isNaN(Number(ResourceManager.m_expansionCssPaYNudge[statsName])))
         {
            return Number(ResourceManager.m_expansionCssPaYNudge[statsName]);
         }
         return ResourceManager.CSS_PA_Y_NUDGE;
      }

      public static function getClassicPaYNudge(statsName:String) : Number
      {
         if(Boolean(statsName) && Boolean(ResourceManager.m_expansionClassicPaYNudge[statsName] != null) && !isNaN(Number(ResourceManager.m_expansionClassicPaYNudge[statsName])))
         {
            return Number(ResourceManager.m_expansionClassicPaYNudge[statsName]);
         }
         return ResourceManager.CLASSIC_PA_Y_NUDGE;
      }

      public static function bitmapDataToFittedMC(bd:BitmapData, targetW:Number, targetH:Number, vAlign:String = null) : MovieClip
      {
         var wrap:MovieClip = null;
         var bmp:Bitmap = null;
         var scale:Number = NaN;
         var scaledW:Number = NaN;
         var scaledH:Number = NaN;
         if(!bd)
         {
            return null;
         }
         if(targetW <= 0 || Boolean(isNaN(targetW)))
         {
            targetW = Number(ResourceManager.FALLBACK_STOCK_SIZE);
         }
         if(targetH <= 0 || Boolean(isNaN(targetH)))
         {
            targetH = targetW;
         }
         if(!vAlign)
         {
            vAlign = ResourceManager.ALIGN_CENTER;
         }
         wrap = new MovieClip();
         bmp = new Bitmap(bd.clone());
         bmp.smoothing = true;
         scale = Math.min(targetW / Math.max(1,bd.width),targetH / Math.max(1,bd.height));
         bmp.scaleX = scale;
         bmp.scaleY = scale;
         scaledW = bd.width * scale;
         scaledH = bd.height * scale;
         bmp.x = -scaledW * 0.5;
         if(vAlign == ResourceManager.ALIGN_BOTTOM)
         {
            bmp.y = -scaledH;
         }
         else if(vAlign == ResourceManager.ALIGN_TOP)
         {
            bmp.y = 0;
         }
         else
         {
            bmp.y = -scaledH * 0.5;
         }
         wrap.addChild(bmp);
         return wrap;
      }

      public static function getLiveSeriesIconMC(seriesIcon:String) : MovieClip
      {
         var icon:MovieClip = null;
         if(!seriesIcon || seriesIcon == "smash_symbol")
         {
            return null;
         }
         if(ExpansionCharacterPacks.isExpansionStatsName(seriesIcon))
         {
            return null;
         }
         icon = instantiateLibraryClass(seriesIcon);
         if(Boolean(icon))
         {
            return icon;
         }
         return ExpansionLibraryResources.tryGetLibraryMCPatch(seriesIcon);
      }

      public static function getRosterSeriesIconMC(statsName:String) : MovieClip
      {
         var blit:Object = null;
         var wrap:MovieClip = null;
         var bmp:Bitmap = null;
         var svg:String = null;
         var icon:MovieClip = null;
         if(!statsName)
         {
            return null;
         }
         blit = ResourceManager.m_rosterSeriesIconBlit[statsName];
         if(Boolean(blit) && Boolean(blit.bd))
         {
            if(shouldTraceUiLink(statsName))
            {
               GameLog.write("[ResourceManager] seriesIcon " + statsName + " -> blit");
            }
            wrap = new MovieClip();
            bmp = new Bitmap(blit.bd as BitmapData);
            bmp.smoothing = true;
            bmp.x = Number(blit.x || 0);
            bmp.y = Number(blit.y || 0);
            wrap.addChild(bmp);
            return wrap;
         }
         svg = String(ResourceManager.m_rosterSeriesIconSvg[statsName] || "");
         if(Boolean(svg) && Boolean(vectorIcon("hasVisibleContent",svg)))
         {
            if(!vectorIcon("hasEmbeddedImage",svg))
            {
               icon = vectorIcon("toMovieClip",svg) as MovieClip;
               if(Boolean(icon))
               {
                  if(shouldTraceUiLink(statsName))
                  {
                     GameLog.write("[ResourceManager] seriesIcon " + statsName + " -> svg");
                  }
                  return icon;
               }
            }
         }
         icon = ExpansionLibraryResources.tryGetLibraryMCPatch(statsName + "_icon");
         if(Boolean(icon))
         {
            if(shouldTraceUiLink(statsName))
            {
               GameLog.write("[ResourceManager] seriesIcon " + statsName + " -> patch icon");
            }
            return icon;
         }
         if(shouldTraceUiLink(statsName))
         {
            GameLog.write("[ResourceManager] seriesIcon " + statsName + " -> MISS");
         }
         return null;
      }

      public static function vectorIcon(op:String, a:* = null, b:* = null) : *
      {
         return VectorIconSvg.dispatch(op,a,b);
      }

      public static function shouldTraceUiLink(name:String) : Boolean
      {
         return TRACE_UI_LINKS && ResourceManager.UI_LINK_DEBUG && Boolean(name);
      }

      public static function refreshCssPortraitIfSelected(statsName:String) : void
      {
         var menu:* = undefined;
         var i:int = 0;
         var settings:* = undefined;
         var expansion:Number = NaN;
         if(!statsName)
         {
            return;
         }
         try
         {
            menu = MenuController.CurrentCharacterSelectMenu;
            if(!menu || !menu.isOnscreen() || !menu.GameObj || !menu.GameObj.PlayerSettings)
            {
               return;
            }
            i = 0;
            while(i < menu.GameObj.PlayerSettings.length)
            {
               settings = menu.GameObj.PlayerSettings[i];
               if(Boolean(settings) && String(settings.character) == statsName)
               {
                  expansion = settings.expansion != null ? Number(settings.expansion) : -1;
                  menu.changePic(i + 1,statsName,expansion);
               }
               i++;
            }
         }
         catch(err:*)
         {
         }
      }

      public static function instantiateLibraryClass(className:String) : MovieClip
      {
         var myClass:Class = null;
         var obj:* = undefined;
         var wrap:MovieClip = null;
         if(!className)
         {
            return null;
         }
         myClass = ResourceManager.getLibraryClass(className);
         if(!myClass)
         {
            return null;
         }
         obj = new myClass();
         if(obj is MovieClip)
         {
            return obj as MovieClip;
         }
         if(obj is DisplayObject)
         {
            wrap = new MovieClip();
            wrap.addChild(obj as DisplayObject);
            return wrap;
         }
         return null;
      }

      public static function getSafeUiIconMC(mcName:String) : MovieClip
      {
         var stock:MovieClip = null;
         if(!mcName)
         {
            return null;
         }
         if(ExpansionCharacterPacks.isExpansionStatsName(mcName))
         {
            stock = getExpansionStockMC(mcName);
            if(Boolean(stock))
            {
               return stock;
            }
            stock = ExpansionLibraryResources.tryGetLibraryMCPatch(mcName);
            if(Boolean(stock))
            {
               return stock;
            }
            return instantiateLibraryClass("smash_symbol");
         }
         if(mcName.indexOf("_icon") == mcName.length - 5)
         {
            stock = instantiateLibraryClass(mcName);
            if(Boolean(stock))
            {
               return stock;
            }
            stock = ExpansionLibraryResources.tryGetLibraryMCPatch(mcName);
            if(Boolean(stock))
            {
               return stock;
            }
            return instantiateLibraryClass("smash_symbol");
         }
         stock = instantiateLibraryClass(mcName);
         if(Boolean(stock))
         {
            return stock;
         }
         stock = ExpansionLibraryResources.tryGetLibraryMCPatch(mcName);
         if(Boolean(stock))
         {
            return stock;
         }
         return instantiateLibraryClass("smash_symbol");
      }
   }
}
