package
{
	import flash.display.Sprite;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	import com.mcleodgaming.ssf2.menus.ReplaySelectMenu;
	import com.mcleodgaming.ssf2.util.GameLog;

	/**
	 * Vault → Replays opens PSB-style ReplaySelectMenu instead of the file picker.
	 */
	public class ReplayBrowserMod extends Sprite
	{
		private var m_host:*;
		private var m_menu:ReplaySelectMenu;

		public function ReplayBrowserMod()
		{
			super();
			m_menu = null;
		}

		public function onBoot(host:*):void
		{
			m_host = host;
			if (!host)
			{
				return;
			};
			host.addHook("VAULT_REPLAY", onVaultReplay);
			host.addHook("MENU_SHOW", onMenuShow);
			host.addHook("MODE_START", onReplayMatch);
		}

		public function onBootEnd():void
		{
			if (m_host)
			{
				try
				{
					m_host["removeHook"]("VAULT_REPLAY", onVaultReplay);
					m_host["removeHook"]("MENU_SHOW", onMenuShow);
					m_host["removeHook"]("MODE_START", onReplayMatch);
				}
				catch (err:*)
				{
					trace("[replay_browser] onBootEnd failed: " + err);
				};
			};
			if (m_menu && m_menu.isOnscreen())
			{
				try
				{
					m_menu.removeSelf();
				}
				catch (closeErr:*)
				{
					trace("[replay_browser] close on teardown failed: " + closeErr);
				};
			};
			m_host = null;
			m_menu = null;
		}

		private function onVaultReplay(ctx:Object):void
		{
			var MC:*;
			var vault:*;
			if (!ctx)
			{
				return;
			};
			ctx.cancel = true;
			try
			{
				MC = getDefinitionByName("com.mcleodgaming.ssf2.controllers.MenuController");
				vault = ctx["menu"] || (MC ? MC["vaultMenu"] : null);
				if (vault && vault["removeSelf"] is Function)
				{
					vault["removeSelf"]();
				};
				if (!m_menu)
				{
					m_menu = new ReplaySelectMenu();
				};
				m_menu.show();
			}
			catch (err:*)
			{
				trace("[replay_browser] open failed: " + err);
				ctx.cancel = false;
			};
		}

		/** Results send a finished replay to the vault. Open this menu instead. */
		private function onMenuShow(ctx:Object):void
		{
			var menu:*;
			var q:String;
			var flag:*;
			if (!ctx || !m_host)
			{
				return;
			};
			menu = ctx["menu"];
			q = menu ? getQualifiedClassName(menu) : "";
			if (q.indexOf("TitleMenu") >= 0)
			{
				try
				{
					m_host.setSessionFlag("replay_browser.return", null);
				}
				catch (clearErr:*)
				{
				};
				return;
			};
			if (q.indexOf("VaultMenu") < 0)
			{
				return;
			};
			try
			{
				flag = m_host.getSessionFlag("replay_browser.return", null);
			}
			catch (flagErr:*)
			{
				flag = null;
			};
			if (!flag)
			{
				return;
			};
			try
			{
				m_host.setSessionFlag("replay_browser.return", null);
			}
			catch (doneErr:*)
			{
			};
			try
			{
				if (menu && menu["removeSelf"] is Function)
				{
					menu["removeSelf"]();
				};
				if (!m_menu)
				{
					m_menu = new ReplaySelectMenu();
				};
				m_menu.show();
				GameLog.write("[replay_browser] return to replay menu");
			}
			catch (openErr:*)
			{
				trace("[replay_browser] return failed: " + openErr);
			};
		}

		/** Drop leftover menus when a replay match starts. Space art is only the Space BG pick. */
		private function onReplayMatch(ctx:Object):void
		{
			var game:*;
			var MC:*;
			if (!ctx)
			{
				return;
			};
			game = ctx["game"];
			if (!game || !game["ReplayDataObj"])
			{
				return;
			};
			try
			{
				MC = getDefinitionByName("com.mcleodgaming.ssf2.controllers.MenuController");
				if (MC && MC["removeAllMenus"] is Function)
				{
					MC["removeAllMenus"]();
				};
			}
			catch (menuErr:*)
			{
			};
			if (m_menu)
			{
				try
				{
					if (m_menu.isOnscreen())
					{
						m_menu.removeSelf();
					};
				}
				catch (selfErr:*)
				{
				};
			};
		}
	}
}
