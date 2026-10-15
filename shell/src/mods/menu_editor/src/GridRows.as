package
{
	/**
	 * Select-screen grid model shared by the CSS and Stage editors. A page is an
	 * Array of rows; a row is an Array of id Strings. Pure functions, no engine refs.
	 */
	public class GridRows
	{
		public static const PINNED:Array = ["random"];

		public static function isPinned(id:String):Boolean
		{
			return (PINNED.indexOf(id) >= 0);
		}

		/** Arrays pass through; JSON objects with "0".."n" keys become Arrays; anything else is null. */
		public static function asList(src:*):Array
		{
			var out:Array;
			var i:int;
			var n:int;
			if (src is Array)
			{
				return (src as Array);
			};
			if (!src || !(src is Object))
			{
				return (null);
			};
			n = 0;
			while (src.hasOwnProperty(String(n)))
			{
				n++;
			};
			if (n <= 0)
			{
				return (null);
			};
			out = [];
			i = 0;
			while (i < n)
			{
				out.push(src[i]);
				i++;
			};
			return (out);
		}

		public static function toRows(src:*):Array
		{
			var out:Array;
			var list:Array;
			var r:int;
			var cells:Array;
			list = asList(src);
			if (!list)
			{
				return (null);
			};
			out = [];
			r = 0;
			while (r < list.length)
			{
				cells = asList(list[r]);
				out.push(cells ? cells.concat() : []);
				r++;
			};
			return (out);
		}

		/** Rows from a saved value: a JSON string, an Array, or a JSON object. Null when empty or unparsable. */
		public static function parseRows(raw:*):Array
		{
			if (raw == null || raw == "")
			{
				return (null);
			};
			if (raw is String)
			{
				try
				{
					return (toRows(JSON.parse(String(raw))));
				}
				catch (err:*)
				{
					return (null);
				};
			};
			return (toRows(raw));
		}

		public static function cloneRows(src:Array):Array
		{
			var out:Array;
			var r:int;
			out = [];
			if (!src)
			{
				return (out);
			};
			r = 0;
			while (r < src.length)
			{
				out.push((src[r] as Array).concat());
				r++;
			};
			return (out);
		}

		public static function flatten(rows:Array):Array
		{
			var out:Array;
			var r:int;
			var c:int;
			var line:Array;
			out = [];
			if (!rows)
			{
				return (out);
			};
			r = 0;
			while (r < rows.length)
			{
				line = rows[r] as Array;
				if (line)
				{
					c = 0;
					while (c < line.length)
					{
						out.push(String(line[c]));
						c++;
					};
				};
				r++;
			};
			return (out);
		}

		public static function inRows(rows:Array, id:String):Boolean
		{
			return (flatten(rows).indexOf(id) >= 0);
		}

		public static function rowOf(rows:Array, id:String):int
		{
			var r:int;
			r = 0;
			while (r < rows.length)
			{
				if ((rows[r] as Array) && (rows[r] as Array).indexOf(id) >= 0)
				{
					return (r);
				};
				r++;
			};
			return (-1);
		}

		public static function colOf(rows:Array, id:String):int
		{
			var r:int;
			r = rowOf(rows, id);
			return (r >= 0 ? (rows[r] as Array).indexOf(id) : -1);
		}

		/** Drops the first copy of id from each row. dropEmpty also removes rows left empty. */
		public static function removeId(rows:Array, id:String, dropEmpty:Boolean = false):void
		{
			var r:int;
			var c:int;
			var line:Array;
			r = 0;
			while (r < rows.length)
			{
				line = rows[r] as Array;
				if (line)
				{
					c = line.indexOf(id);
					if (c >= 0)
					{
						line.splice(c, 1);
					};
					if (dropEmpty && line.length <= 0)
					{
						rows.splice(r, 1);
						continue;
					};
				};
				r++;
			};
		}

		/** Inserts at (row, col); col is clamped to the row; a row past the end becomes a new row. */
		public static function insertAt(rows:Array, row:int, col:int, id:String):void
		{
			var line:Array;
			if (row < 0)
			{
				return;
			};
			if (row >= rows.length)
			{
				rows.push([id]);
				return;
			};
			line = rows[row] as Array;
			if (!line)
			{
				rows[row] = [id];
				return;
			};
			if (col < 0)
			{
				col = 0;
			};
			if (col > line.length)
			{
				col = line.length;
			};
			line.splice(col, 0, id);
		}

		/**
		 * Moves id to (row, col). newRow appends a row, or joins the last row when maxRows is reached.
		 * sameRowShift accounts for the gap left by id when it moves right within its own row.
		 */
		public static function moveId(rows:Array, id:String, row:int, col:int, newRow:Boolean, sameRowShift:Boolean, maxRows:int):void
		{
			var fromRow:int;
			var fromCol:int;
			fromRow = rowOf(rows, id);
			fromCol = colOf(rows, id);
			removeId(rows, id);
			if (newRow)
			{
				if (rows.length >= maxRows && rows.length > 0)
				{
					(rows[rows.length - 1] as Array).push(id);
				}
				else
				{
					rows.push([id]);
				};
			}
			else if (sameRowShift && fromRow == row && fromCol >= 0 && fromCol < col)
			{
				insertAt(rows, row, col - 1, id);
			}
			else
			{
				insertAt(rows, row, col, id);
			};
		}

		/** Last row, before the first pinned id in it. */
		public static function insertBeforePinned(rows:Array, id:String):void
		{
			var last:Array;
			var i:int;
			if (!rows || rows.length <= 0)
			{
				rows.push([id]);
				return;
			};
			last = rows[rows.length - 1] as Array;
			if (!last)
			{
				last = [];
				rows[rows.length - 1] = last;
			};
			i = 0;
			while (i < last.length)
			{
				if (isPinned(String(last[i])))
				{
					last.splice(i, 0, id);
					return;
				};
				i++;
			};
			last.push(id);
		}

		/** Pushes each id from ids onto dest when it is in neither dest nor rows. */
		public static function appendMissing(dest:Array, ids:Array, rows:Array):void
		{
			var i:int;
			var id:String;
			if (!ids)
			{
				return;
			};
			i = 0;
			while (i < ids.length)
			{
				id = String(ids[i]);
				if (id && dest.indexOf(id) < 0 && !inRows(rows, id))
				{
					dest.push(id);
				};
				i++;
			};
		}

		/** New rows holding only ids where keep(id) is true. Empty rows after the first are dropped; at least one row. */
		public static function filterIds(rows:Array, keep:Function):Array
		{
			var out:Array;
			var r:int;
			var c:int;
			var line:Array;
			var next:Array;
			var id:String;
			out = [];
			r = 0;
			while (rows && r < rows.length)
			{
				line = rows[r] as Array;
				next = [];
				c = 0;
				while (line && c < line.length)
				{
					id = String(line[c]);
					if (keep(id))
					{
						next.push(id);
					};
					c++;
				};
				if (next.length > 0 || r == 0)
				{
					out.push(next);
				};
				r++;
			};
			if (out.length < 1)
			{
				out.push([]);
			};
			return (out);
		}

		/** Adds id to the first row with room, else a new row. False when id is already there or the page is full. */
		public static function tryAdd(rows:Array, id:String, maxCols:int, maxRows:int):Boolean
		{
			var r:int;
			var line:Array;
			if (!id || !rows || inRows(rows, id))
			{
				return (false);
			};
			r = 0;
			while (r < rows.length)
			{
				line = rows[r] as Array;
				if (!line)
				{
					line = [];
					rows[r] = line;
				};
				if (line.length < maxCols)
				{
					line.push(id);
					return (true);
				};
				r++;
			};
			if (rows.length < maxRows)
			{
				rows.push([id]);
				return (true);
			};
			return (false);
		}

		/** Spills ids past maxCols into the next row, up to maxRows rows. Rows past maxRows are dropped. */
		public static function overflow(rows:Array, maxCols:int, maxRows:int):void
		{
			var r:int;
			var line:Array;
			var extra:Array;
			var next:Array;
			if (!rows)
			{
				return;
			};
			r = 0;
			while (r < rows.length && r < maxRows)
			{
				line = rows[r] as Array;
				if (!line)
				{
					r++;
					continue;
				};
				while (line.length > maxCols)
				{
					extra = line.splice(maxCols, line.length - maxCols);
					if (r + 1 >= rows.length)
					{
						if (rows.length >= maxRows)
						{
							break;
						};
						rows.push([]);
					};
					next = rows[r + 1] as Array;
					if (!next)
					{
						next = [];
					};
					rows[r + 1] = extra.concat(next);
					line = rows[r] as Array;
				};
				r++;
			};
			while (rows.length > maxRows)
			{
				rows.pop();
			};
		}

		/** overflow, then folds pinned ids from rows past maxRows into the last kept row. */
		public static function cap(rows:Array, maxCols:int, maxRows:int):Array
		{
			var extra:Array;
			var last:Array;
			var i:int;
			var id:String;
			overflow(rows, maxCols, maxRows);
			while (rows.length > maxRows && rows.length > 1)
			{
				extra = rows.pop() as Array;
				last = rows[rows.length - 1] as Array;
				if (!last)
				{
					last = [];
					rows[rows.length - 1] = last;
				};
				i = 0;
				while (extra && i < extra.length)
				{
					id = String(extra[i]);
					if (isPinned(id) && last.indexOf(id) < 0)
					{
						last.push(id);
					};
					i++;
				};
			};
			overflow(rows, maxCols, maxRows);
			return (rows);
		}

		/** n clamped to 1..maxPages. */
		public static function clampPages(n:int, maxPages:int):int
		{
			if (n < 1)
			{
				n = 1;
			};
			if (n > maxPages)
			{
				n = maxPages;
			};
			return (n);
		}

		/** Grows with empty pages or pops trailing pages until pages.length is n (clamped, at least 1). */
		public static function resizePages(pages:Array, n:int, maxPages:int):void
		{
			n = clampPages(n, maxPages);
			while (pages.length < n)
			{
				pages.push([[]]);
			};
			while (pages.length > n && pages.length > 1)
			{
				pages.pop();
			};
		}

		/** Saved page list to pages, at most maxPages; an empty page becomes [[]]. Null when there are none. */
		public static function toPages(raw:*, maxPages:int):Array
		{
			var list:Array;
			var out:Array;
			var i:int;
			var rows:Array;
			list = asList(raw);
			if (!list || list.length <= 0)
			{
				return (null);
			};
			out = [];
			i = 0;
			while (i < list.length && out.length < maxPages)
			{
				rows = toRows(list[i]);
				out.push(rows && rows.length > 0 ? rows : [[]]);
				i++;
			};
			return (out.length > 0 ? out : null);
		}

		/**
		 * Puts id on the first page with room (each page is maxCols x maxRows), else on a new page.
		 * Returns the page index, or -1 when every page is full and maxPages is reached.
		 */
		public static function placeOnFirstOpenPage(pages:Array, id:String, maxCols:int, maxRows:int, maxPages:int):int
		{
			var p:int;
			var rows:Array;
			if (!id || !pages)
			{
				return (-1);
			};
			p = 0;
			while (p < pages.length)
			{
				rows = cloneRows(pages[p] ? (pages[p] as Array) : [[]]);
				if (tryAdd(rows, id, maxCols, maxRows))
				{
					overflow(rows, maxCols, maxRows);
					pages[p] = rows;
					return (p);
				};
				p++;
			};
			if (pages.length >= maxPages)
			{
				return (-1);
			};
			pages.push([[id]]);
			return (pages.length - 1);
		}
	}
}
