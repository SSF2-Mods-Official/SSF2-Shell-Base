package
{
	import flash.display.Sprite;
	import flash.utils.getDefinitionByName;
	import com.mcleodgaming.ssf2.menus.ReplaySelectMenu;

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
		}

		public function onBootEnd():void
		{
			if (m_host)
			{
				try
				{
					m_host["removeHook"]("VAULT_REPLAY", onVaultReplay);
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
	}
}
