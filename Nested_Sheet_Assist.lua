-- VECTRIC LUA SCRIPT
-- Nested Sheet Assist
-- Complete Toolpath Synchronization, ATC Export & Job Setup Sheet PDF Generator

require "strict"

-- Pre-declare globals needed for Setup_Sheet compatibility
svgpath = ""
vStrCount = 0
gBoundaryVectorLayerName = "xxSetupSheetBoundary"
gJobSetUpV = "Job Setup Sheet v3.9"
g_VectricGadgetSignature = "FF44DDEE668844338800111144DD44BBCCEEFF99EEAA2211225500BB44CCFF99AA9999AABBBBFFBBAAEEEEEE4466BBBB9977BBEE4422DDDD22EEBBCCCCAA9988"
g_OutputPath = ""

g_version     = "1.0"
g_title       = "Nested Sheet Assist"
g_gadget_name = "NestedSheetAssist"

g_default_window_width  = 780
g_default_window_height = 720

g_options = {
   templatePath         = "",
   windowWidth          = g_default_window_width,
   windowHeight         = g_default_window_height,
   postOutputFolder     = "",
   postName             = "",
   useActiveSheet       = false,
   onlyVisibleToolpaths = true
}

g_log_buffer = ""

function WriteDebugLog(msg)
   pcall(function()
      local temp_dir = os.getenv("TEMP") or "C:\\Windows\\Temp"
      local f = io.open(temp_dir .. "\\nested_sheet_assist_debug.log", "a")
      if f ~= nil then
         f:write(os.date("%Y-%m-%d %H:%M:%S") .. " " .. tostring(msg) .. "\n")
         f:close()
      end
   end)
end

function ClearLog(dialog)
   g_log_buffer = ""
   WriteDebugLog("--- ClearLog ---")
   if dialog ~= nil then
      pcall(function() dialog:UpdateTextField("StatusLogLabel", "Starting...") end)
      pcall(function() dialog:UpdateLabelField("StatusLogLabel", "Starting...") end)
   end
end

function LogMsg(dialog, msg)
   WriteDebugLog(msg)
   if g_log_buffer == "" then
      g_log_buffer = msg
   else
      g_log_buffer = g_log_buffer .. "\n" .. msg
   end
   if dialog ~= nil then
      pcall(function() dialog:UpdateTextField("StatusLogLabel", g_log_buffer) end)
      pcall(function() dialog:UpdateLabelField("StatusLogLabel", g_log_buffer) end)
   end
end

function GetProjectKey(job)
   if job ~= nil and job.Exists and job.Name ~= nil and job.Name ~= "" then
      local clean_key = string.gsub(job.Name, "[^%w]", "_")
      return clean_key
   end
   return "DefaultProject"
end

function GetJobDirectory(job)
   if job ~= nil and job.Exists and job.Name ~= nil and job.Name ~= "" then
      local dir = string.match(job.Name, "^(.*)[/\\][^/\\]*$")
      if dir ~= nil and dir ~= "" then
         return dir
      end
   end
   return ""
end

function SaveDefaults(options, job)
   local registry = Registry(g_gadget_name)
   registry:SetString("templatePath", options.templatePath)
   registry:SetString("postName", options.postName)
   registry:SetInt("WindowWidth", options.windowWidth)
   registry:SetInt("WindowHeight", options.windowHeight)
   registry:SetString("lastOutputFolder", options.postOutputFolder)
   registry:SetBool("useActiveSheet", options.useActiveSheet)
   registry:SetBool("onlyVisibleToolpaths", options.onlyVisibleToolpaths)

   local proj_key = GetProjectKey(job)
   if proj_key ~= "DefaultProject" and options.postOutputFolder ~= "" then
      registry:SetString("folder_" .. proj_key, options.postOutputFolder)
   end
end

function LoadDefaults(options, job)
   local registry = Registry(g_gadget_name)
   options.templatePath         = registry:GetString("templatePath", options.templatePath)
   options.postName             = registry:GetString("postName", options.postName)
   options.useActiveSheet       = registry:GetBool("useActiveSheet", options.useActiveSheet)
   options.onlyVisibleToolpaths = registry:GetBool("onlyVisibleToolpaths", true)
   local w = registry:GetInt("WindowWidth", options.windowWidth)
   local h = registry:GetInt("WindowHeight", options.windowHeight)
   if w > 0 then options.windowWidth = w end
   if h > 0 then options.windowHeight = h end

   local proj_key = GetProjectKey(job)
   local proj_folder = ""
   if proj_key ~= "DefaultProject" then
      proj_folder = registry:GetString("folder_" .. proj_key, "")
   end

   if proj_folder ~= "" then
      options.postOutputFolder = proj_folder
   else
      local job_dir = GetJobDirectory(job)
      if job_dir ~= "" then
         options.postOutputFolder = job_dir
      else
         options.postOutputFolder = registry:GetString("lastOutputFolder", options.postOutputFolder)
      end
   end
end

function SanitizeFileName(name, default_name)
   if name == nil or name == "" then
      return default_name
   end
   local clean = string.gsub(name, "[\\/:%*%?\"<>|]", "_")
   clean = string.gsub(clean, "^%s*(.-)%s*$", "%1")
   if clean == "" then
      return default_name
   end
   return clean
end

function PopulatePostDropDownList(dialog, drop_down_html_id, default_post)
   local toolpath_saver = ToolpathSaver()

   if (default_post == nil) or (default_post == "") then
      local default_pp = toolpath_saver.DefaultPost
      if default_pp ~= nil then
         default_post = default_pp.Name
      else
         default_post = ""
      end
   end

   dialog:AddDropDownList(drop_down_html_id, default_post)

   local num_posts = toolpath_saver:GetNumPosts()
   local post_index = 0

   while post_index < num_posts do
      local post = toolpath_saver:GetPostAtIndex(post_index)
      dialog:AddDropDownListValue(drop_down_html_id, post.Name)
      post_index = post_index + 1
   end
end

function UpdateOptionsFromDialog(dialog, options)
   options.windowWidth  = dialog.WindowWidth
   options.windowHeight = dialog.WindowHeight

   local template_path = ""
   pcall(function() template_path = dialog:GetLabelField("TemplateFileNameLabel") end)
   if template_path ~= nil and template_path ~= "(No template selected)" and template_path ~= "" then
      options.templatePath = template_path
   end

   options.postOutputFolder = dialog:GetTextField("PostOutputFolderEdit")
   options.postName = dialog:GetDropDownListValue("PostNameSelector")
   pcall(function() options.useActiveSheet = dialog:GetCheckBox("UseActiveSheetCheck") end)
   pcall(function() options.onlyVisibleToolpaths = dialog:GetCheckBox("OnlyVisibleToolpathsCheck") end)
   return true
end

function OnLuaButton_ChooseTemplateFileButton(dialog)
   local file_dialog = FileDialog()
   if not file_dialog:FileOpen(
      "ToolpathTemplate",
      g_options.templatePath,
      "Toolpath Templates (*.ToolpathTemplate;*.vctemplate)|*.ToolpathTemplate;*.vctemplate|All Files (*.*)|*.*||"
   ) then
      return false
   end

   g_options.templatePath = file_dialog.PathName
   pcall(function() dialog:UpdateLabelField("TemplateFileNameLabel", g_options.templatePath) end)
   LogMsg(dialog, "Selected Template: " .. g_options.templatePath)
   return true
end

function OnLuaButton_UseActiveSheetCheck(dialog)
   UpdateOptionsFromDialog(dialog, g_options)
   if g_options.useActiveSheet then
      LogMsg(dialog, "Mode: Active Sheet Toolpaths.")
   else
      LogMsg(dialog, "Mode: External Template File.")
   end
   return true
end

function OnLuaButton_OnlyVisibleToolpathsCheck(dialog)
   UpdateOptionsFromDialog(dialog, g_options)
   if g_options.onlyVisibleToolpaths then
      LogMsg(dialog, "Filter: Copying ONLY visible (checked) toolpaths.")
   else
      LogMsg(dialog, "Filter: Copying ALL toolpaths on active sheet.")
   end
   return true
end

function IsToolpathOnSheet(tp, s_id, s_idx, s_name, num_sheets)
   if tp == nil then return false end

   -- 1. Match by SheetId UUID
   if s_id ~= nil and tp.SheetId ~= nil then
      local matched = false
      pcall(function()
         local u1 = luaUUID(tp.SheetId)
         local u2 = luaUUID(s_id)
         if u1:IsEqual(u2) or u1:AsString() == u2:AsString() then
            matched = true
         end
      end)
      if matched then return true end
   end

   -- 2. Match by Name pattern
   local name = tp.Name
   if type(name) == "string" then
      if string.match(name, "^S" .. s_idx .. "%-") then return true end
      if string.match(name, "^Sheet%s*" .. s_idx .. "[%-_%s]") then return true end
      if s_name ~= nil and s_name ~= "" then
         if string.match(name, "^" .. s_name .. "%-") then return true end
         if string.find(name, s_name, 1, true) then return true end
      end
   end

   -- 3. Fallback if only 1 sheet
   if num_sheets <= 1 then return true end

   return false
end

function CheckOtherSheetsHaveToolpaths(job, toolpath_manager)
   local sheet_manager = job.SheetManager
   if sheet_manager == nil or sheet_manager.NumberOfSheets <= 1 then
      return false, 0
   end

   local active_sheet_id = sheet_manager.ActiveSheetId
   local other_count = 0

   local pos = toolpath_manager:GetHeadPosition()
   while pos ~= nil do
      local tp = nil
      tp, pos = toolpath_manager:GetNext(pos)
      if tp ~= nil and tp.SheetId ~= nil and active_sheet_id ~= nil then
         local is_on_active = false
         pcall(function()
            if luaUUID(tp.SheetId):IsEqual(luaUUID(active_sheet_id)) then
               is_on_active = true
            end
         end)
         if not is_on_active then
            other_count = other_count + 1
         end
      end
   end

   return (other_count > 0), other_count
end

function ExecuteApplyToolpaths(dialog, job, toolpath_manager, do_save, post, output_folder)
   UpdateOptionsFromDialog(dialog, g_options)

   local sheet_manager = job.SheetManager
   local num_sheets = 1
   if sheet_manager ~= nil then
      num_sheets = sheet_manager.NumberOfSheets
   end

   local orig_active_sheet_id = nil
   if sheet_manager ~= nil then
      orig_active_sheet_id = sheet_manager.ActiveSheetId
   end

   -- Informational notice if other sheets already have toolpaths
   local other_sheets_have_tp, other_count = CheckOtherSheetsHaveToolpaths(job, toolpath_manager)
   if other_sheets_have_tp then
      LogMsg(dialog, "ℹ Note: " .. other_count .. " existing toolpath(s) already exist on other sheets.")
   end

   local template_file = ""

   if g_options.useActiveSheet then
      if toolpath_manager.Count == 0 then
         LogMsg(dialog, "❌ Error: No toolpaths found in project.")
         MessageBox("No toolpaths found in the project. Please create toolpaths on the active sheet first.")
         return false
      end

      local num_visible = 0
      pcall(function() num_visible = toolpath_manager.NumVisibleToolpaths end)

      if g_options.onlyVisibleToolpaths then
         if num_visible == 0 then
            local alert_msg = "No toolpaths are currently marked as visible (checked) on the active sheet!\n\n" ..
                              "Please check/mark the box next to each toolpath you want to copy in the Toolpaths tab before running."
            LogMsg(dialog, "❌ Error: No visible (checked) toolpaths selected on active sheet.")
            MessageBox(alert_msg)
            return false
         end
         LogMsg(dialog, "Capturing " .. num_visible .. " visible (checked) toolpath(s) from active sheet...")
      else
         pcall(function() toolpath_manager:SetAllToolpathsVisibility(true) end)
         LogMsg(dialog, "Capturing all " .. toolpath_manager.Count .. " toolpaths from active sheet...")
      end

      local temp_dir = os.getenv("TEMP") or "C:\\Windows\\Temp"
      template_file = temp_dir .. "\\vectric_active_sheet_temp.ToolpathTemplate"

      local saved = false
      pcall(function() saved = toolpath_manager:SaveVisibleToolpathsAsTemplate(template_file) end)
      if not saved then
         pcall(function() saved = toolpath_manager:SaveToolpathTemplate(template_file) end)
      end

      local f = io.open(template_file, "rb")
      if f ~= nil then
         f:close()
         LogMsg(dialog, "✔ Toolpath snapshot captured.")
      else
         template_file = temp_dir .. "\\vectric_active_sheet_temp.vctemplate"
         pcall(function() saved = toolpath_manager:SaveVisibleToolpathsAsTemplate(template_file) end)
         f = io.open(template_file, "rb")
         if f ~= nil then
            f:close()
            LogMsg(dialog, "✔ Toolpath snapshot captured as .vctemplate.")
         else
            LogMsg(dialog, "❌ Error: Failed to save temporary template file.")
            MessageBox("Could not generate toolpath template.")
            return false
         end
      end
   else
      template_file = g_options.templatePath
      if template_file == "" or template_file == "(No template selected)" then
         LogMsg(dialog, "❌ Error: Please select a Toolpath Template (.vctemplate) first or check 'Use Active Sheet's Toolpaths'.")
         MessageBox("Please select a Toolpath Template (.vctemplate) first.")
         return false
      end
   end

   LogMsg(dialog, "Applying toolpaths across all " .. num_sheets .. " sheet(s)...")

   -- Load template into job (VCarve prompts once: apply to all sheets)
   if not toolpath_manager:LoadToolpathTemplate(template_file) then
      LogMsg(dialog, "❌ Failed to load toolpath template: " .. template_file)
      MessageBox("Failed to load toolpath template.")
      return false
   end

   -- NO DELETIONS AT ALL: All toolpaths remain completely safe and untouched!
   if g_options.useActiveSheet then
      pcall(function() os.remove(template_file) end)
   end

   LogMsg(dialog, "Calculating toolpaths on each active sheet...")

   -- Activate each sheet in the viewport while recalculating
   local total_calced = 0
   if sheet_manager ~= nil and num_sheets > 0 then
      local sheet_ids = sheet_manager:GetSheetIds()
      local s_idx = 0
      for s_id in sheet_ids do
         s_idx = s_idx + 1
         local s_name = sheet_manager:GetSheetName(s_id)
         local s_display = s_name or ("Sheet " .. s_idx)
         
         sheet_manager.ActiveSheetId = s_id
         job:Refresh2DView()
         LogMsg(dialog, "\n[" .. s_display .. "] Calculating operations...")

         local pos = toolpath_manager:GetHeadPosition()
         while pos ~= nil do
            local tp = nil
            tp, pos = toolpath_manager:GetNext(pos)
            if tp ~= nil then
               if IsToolpathOnSheet(tp, s_id, s_idx, s_name, num_sheets) then
                  if toolpath_manager:RecalculateToolpath(tp) then
                     total_calced = total_calced + 1
                     LogMsg(dialog, "  ✔ " .. tp.Name .. " -> OK")
                  else
                     LogMsg(dialog, "  ⚠ " .. tp.Name .. " -> Calculation skipped/failed")
                  end
               end
            end
         end
      end

      -- Restore original active sheet
      if orig_active_sheet_id ~= nil then
         sheet_manager.ActiveSheetId = orig_active_sheet_id
         job:Refresh2DView()
      end
   else
      -- Single sheet fallback
      local pos = toolpath_manager:GetHeadPosition()
      while pos ~= nil do
         local tp = nil
         tp, pos = toolpath_manager:GetNext(pos)
         if tp ~= nil then
            if toolpath_manager:RecalculateToolpath(tp) then
               total_calced = total_calced + 1
               LogMsg(dialog, "  ✔ " .. tp.Name .. " -> OK")
            end
         end
      end
   end

   if do_save and post ~= nil and output_folder ~= "" then
      LogMsg(dialog, "\nSaving ATC files for each sheet...")
      return ExecuteSaveToolpathsOnly(dialog, job, post, output_folder)
   else
      local summary_msg = "Toolpaths applied across all sheets! " .. total_calced .. " operations calculated."
      LogMsg(dialog, "\n========================================")
      LogMsg(dialog, "✔ " .. summary_msg)
      return true
   end
end

function ExecuteSaveToolpathsOnly(dialog, job, post, output_folder)
   local toolpath_manager = ToolpathManager()
   if toolpath_manager.Count == 0 then
      LogMsg(dialog, "❌ Error: No toolpaths found in job. Please calculate or apply toolpaths first.")
      MessageBox("No toolpaths found in job. Please apply toolpaths first.")
      return false
   end

   local sheet_manager = job.SheetManager
   local toolpath_saver = ToolpathSaver()
   local saved_count = 0

   local num_sheets = 1
   if sheet_manager ~= nil then
      num_sheets = sheet_manager.NumberOfSheets
   end

   LogMsg(dialog, "Starting ATC Batch Export across " .. num_sheets .. " sheet(s)...")
   LogMsg(dialog, "Post Processor: " .. post.Name)
   LogMsg(dialog, "Output Folder: " .. output_folder)

   if sheet_manager ~= nil and num_sheets > 0 then
      local sheet_ids = sheet_manager:GetSheetIds()
      local s_idx = 0
      local orig_id = sheet_manager.ActiveSheetId

      for s_id in sheet_ids do
         s_idx = s_idx + 1
         sheet_manager.ActiveSheetId = s_id
         job:Refresh2DView()
         toolpath_saver:ClearToolpathList()

         local s_name = sheet_manager:GetSheetName(s_id)
         local s_display = s_name or ("Sheet " .. s_idx)
         LogMsg(dialog, "\n[" .. s_display .. "] Collecting toolpaths...")

         local added = 0
         local pos = toolpath_manager:GetHeadPosition()

         while pos ~= nil do
            local tp = nil
            tp, pos = toolpath_manager:GetNext(pos)
            if tp ~= nil then
               if IsToolpathOnSheet(tp, s_id, s_idx, s_name, num_sheets) then
                  toolpath_saver:AddToolpath(tp)
                  added = added + 1
                  LogMsg(dialog, "  + Found: " .. tp.Name)
               end
            end
         end

         -- Fallback for single sheet if no name match
         if added == 0 and num_sheets == 1 then
            local p2 = toolpath_manager:GetHeadPosition()
            while p2 ~= nil do
               local tp = nil
               tp, p2 = toolpath_manager:GetNext(p2)
               if tp ~= nil then
                  toolpath_saver:AddToolpath(tp)
                  added = added + 1
                  LogMsg(dialog, "  + Found (all): " .. tp.Name)
               end
            end
         end

         if added > 0 then
            local base_name = SanitizeFileName(s_name, "Sheet" .. s_idx)
            local file_name = base_name .. "." .. post.Extension
            local out_path = output_folder .. "\\" .. file_name
            if toolpath_saver:SaveToolpaths(post, out_path, false) then
               saved_count = saved_count + 1
               LogMsg(dialog, "  💾 SAVED: " .. file_name .. " (" .. added .. " operations combined)")
            else
               LogMsg(dialog, "  ❌ FAILED TO SAVE: " .. file_name)
            end
         else
            LogMsg(dialog, "  ⚠ No toolpaths found for this sheet.")
         end
      end

      if orig_id ~= nil then
         sheet_manager.ActiveSheetId = orig_id
         job:Refresh2DView()
      end
   else
      -- Single sheet fallback
      local pos = toolpath_manager:GetHeadPosition()
      local count = 0
      toolpath_saver:ClearToolpathList()
      while pos ~= nil do
         local tp = nil
         tp, pos = toolpath_manager:GetNext(pos)
         if tp ~= nil then
            toolpath_saver:AddToolpath(tp)
            count = count + 1
            LogMsg(dialog, "  + Found: " .. tp.Name)
         end
      end
      if count > 0 then
         local file_name = "Sheet1." .. post.Extension
         local out_path = output_folder .. "\\" .. file_name
         if toolpath_saver:SaveToolpaths(post, out_path, false) then
            saved_count = 1
            LogMsg(dialog, "  💾 SAVED: " .. file_name .. " (" .. count .. " operations combined)")
         else
            LogMsg(dialog, "  ❌ FAILED TO SAVE: " .. file_name)
         end
      end
   end

   local summary_msg = "ATC Save Complete: " .. saved_count .. " NC file(s) saved to:\n" .. output_folder
   LogMsg(dialog, "\n========================================")
   LogMsg(dialog, "✔ " .. summary_msg)
   return true
end

-- Core: Export Job Report (PDF)
function ExecuteExportJobReport(dialog, clear_log)
   local job = VectricJob()
   if not job.Exists then 
      LogMsg(dialog, "❌ Error: No active job found.")
      MessageBox("No active job found.")
      return false 
   end

   pcall(function() setmetatable(_G, nil) end)

   UpdateOptionsFromDialog(dialog, g_options)
   if clear_log then
      ClearLog(dialog)
   end

   if g_options.postOutputFolder == "" then
      LogMsg(dialog, "❌ Error: Please select an Output Folder first.")
      MessageBox("Please select an Output Folder first.")
      return true
   end

   local tp_mgr = ToolpathManager()
   if tp_mgr.Count == 0 then
      LogMsg(dialog, "❌ Error: No toolpaths found. Please calculate toolpaths before generating a report.")
      MessageBox("No toolpaths found in the job. Please create/apply toolpaths first.")
      return true
   end

   -- Read selected sheets from dialog
   local sel_str = "ALL"
   pcall(function() sel_str = dialog:GetTextField("SelectedSheetsData") end)
   local export_all = (sel_str == "ALL" or sel_str == "" or sel_str == nil)
   local selected_sheets_map = {}
   local selected_count = 0

   if not export_all and sel_str ~= "NONE" then
      for s in string.gmatch(sel_str, "([^|]+)") do
         selected_sheets_map[s] = true
         selected_count = selected_count + 1
      end
   end

   if export_all then
      LogMsg(dialog, "Generating Job Setup Report for ALL sheets...")
   else
      LogMsg(dialog, "Generating Job Setup Report for " .. selected_count .. " selected sheet(s)...")
   end

   -- Load Vectric's Setup_Sheet generator (check for custom settings from Job Setup Sheet Editor)
   local custom_setup_script = "C:\\Users\\Public\\Documents\\Vectric Files\\Gadgets\\VCarve Pro V12.5\\__Setup_Sheet\\Setup_Sheet.lua"
   local default_setup_script = "C:\\ProgramData\\Vectric\\VCarve Pro\\V12.5\\Gadgets\\__Setup_Sheet\\Setup_Sheet.lua"
   local setup_script = default_setup_script

   local f_custom = io.open(custom_setup_script, "rb")
   if f_custom ~= nil then
      f_custom:close()
      setup_script = custom_setup_script
      LogMsg(dialog, "Applying custom Setup Sheet settings (from Job Setup Sheet Editor)...")
   end

   local loaded_ok, err = pcall(function() dofile(setup_script) end)
   if not loaded_ok or type(GenerateSetupSheet) ~= "function" then
      if setup_script ~= default_setup_script then
         setup_script = default_setup_script
         loaded_ok, err = pcall(function() dofile(setup_script) end)
      end
      if not loaded_ok or type(GenerateSetupSheet) ~= "function" then
         LogMsg(dialog, "❌ Error loading Setup_Sheet generator: " .. tostring(err))
         MessageBox("Could not load Vectric Setup Sheet generator.")
         return true
      end
   end

   local temp_dir = os.getenv("TEMP") or "C:\\Windows\\Temp"
   local temp_base = temp_dir .. "\\vectric_job_report_temp.html"

   -- Hook Vectric's OutputHtml so no temporary files are written to disk,
   -- and hook GetNumberOfToolpathsOnSheet so unselected sheets are skipped instantly!
   local captured_sheets = {}
   local orig_OutputHtml = OutputHtml
   local orig_GetNumberOfToolpathsOnSheet = GetNumberOfToolpathsOnSheet
   local sheet_mgr = job.SheetManager

   OutputHtml = function(HTMLTable, path, pathext)
      table.insert(HTMLTable, "</body></html>")
      local safe_table = {}
      for _, part in ipairs(HTMLTable) do
         if type(part) == "string" then
            table.insert(safe_table, part)
         end
      end
      local full_html = table.concat(safe_table)
      table.insert(captured_sheets, {
         pathext = pathext or "",
         html = full_html
      })
   end

   if not export_all and type(orig_GetNumberOfToolpathsOnSheet) == "function" and sheet_mgr ~= nil then
      GetNumberOfToolpathsOnSheet = function(sheet_id)
         local s_name = sheet_mgr:GetSheetName(sheet_id)
         local is_sel = false
         if s_name ~= nil and selected_sheets_map[s_name] then
            is_sel = true
         elseif s_name ~= nil then
            pcall(function()
               local p = Path()
               local port = p:MakePortable(s_name)
               if selected_sheets_map[port] then
                  is_sel = true
               end
            end)
         end
         if not is_sel then
            -- Returning 0 tells Setup_Sheet that this sheet has no toolpaths to report.
            -- This cleanly and immediately skips all vector/boundary generation, SVG rendering,
            -- and HTML construction for this sheet in a fraction of a millisecond!
            return 0
         end
         return orig_GetNumberOfToolpathsOnSheet(sheet_id)
      end
   end

   LogMsg(dialog, "Compiling sheet parameters and toolpaths...")
   local gen_ok, gen_err = pcall(function() GenerateSetupSheet(temp_base) end)
   OutputHtml = orig_OutputHtml
   if orig_GetNumberOfToolpathsOnSheet ~= nil then
      GetNumberOfToolpathsOnSheet = orig_GetNumberOfToolpathsOnSheet
   end

   if not gen_ok then
      LogMsg(dialog, "❌ Error generating setup sheets: " .. tostring(gen_err))
      MessageBox("Error generating setup sheets:\n" .. tostring(gen_err))
      return false
   end

   LogMsg(dialog, "Filtering selected sheets (" .. selected_count .. " requested, " .. #captured_sheets .. " compiled)...")

   local combined_body_parts = {}
   local combined_css = ""

   for idx, item in ipairs(captured_sheets) do
      local is_included = export_all
      if not is_included then
         for sel_name, _ in pairs(selected_sheets_map) do
            -- Match exact sheet title tag: "Job Layout <sheet_name></div>"
            local target_tag = '<div class="boxtitle">Job Layout ' .. sel_name .. '</div>'
            if string.find(item.html, target_tag, 1, true) then
               is_included = true
               break
            elseif item.pathext == ("_" .. sel_name) then
               is_included = true
               break
            end
         end
         -- If only 1 sheet exists total, include it
         if not is_included and #captured_sheets == 1 then
            is_included = true
         end
      end

      if is_included then
         local full_html = item.html
         if combined_css == "" then
            combined_css = string.match(full_html, "<style.->(.-)</style>") or ""
         end
         local body_content = string.match(full_html, "<body.->(.-)</body>") or full_html

         -- Expand Job Layout to its own dedicated full page and enlarge the SVG
         body_content = string.gsub(
            body_content,
            '<div class="boxborder"><div class="boxborder"><div class="boxtitle">Job Layout',
            '<div class="boxborder fullpage-layout-box"><div class="boxborder"><div class="boxtitle">Job Layout'
         )
         body_content = string.gsub(body_content, 'width="11cm"', 'width="100%%"')
         body_content = string.gsub(body_content, 'height="5.5cm"', 'height="80vh"')
         body_content = string.gsub(body_content, '<div id="footer">.-</div>', '')
         body_content = string.gsub(body_content, 'Job Setup Sheet v[%d%.]+', '')

         table.insert(combined_body_parts, body_content)
         -- Extract sheet name from title tag for log
         local logged_name = string.match(item.html, '<div class="boxtitle">Job Layout (.-)</div>') or ("Sheet " .. idx)
         LogMsg(dialog, "  ✔ Compiled report for: " .. logged_name)
      end
   end

   if #combined_body_parts == 0 then
      LogMsg(dialog, "❌ Error: No sheet reports were compiled. Ensure toolpaths are calculated on selected sheets.")
      MessageBox("No setup sheet content could be generated. Please make sure toolpaths are present on the selected sheets.")
      return true
   end

   -- Build the unified HTML document with page breaks
   local combined_html_path = temp_dir .. "\\combined_job_report.html"
   local cf = io.open(combined_html_path, "wb")
   if cf == nil then
      LogMsg(dialog, "❌ Error creating combined report HTML.")
      return true
   end

   cf:write("<!DOCTYPE html><html><head><meta http-equiv='Content-Type' content='text/html; charset=utf-8'>\n")
   cf:write("<title>Job Setup Report</title>\n")
   cf:write("<style>\n")
   cf:write(combined_css)
   cf:write("\n@media print {\n")
   cf:write("  @page { margin: 5mm 8mm 5mm 8mm; }\n")
   cf:write("  .sheet-report-wrapper { page-break-before: always !important; break-before: page !important; clear: both !important; }\n")
   cf:write("  .sheet-report-wrapper:first-of-type { page-break-before: avoid !important; break-before: avoid !important; }\n")
   cf:write("  #header { height: 68px !important; margin-bottom: 2px !important; padding-bottom: 2px !important; page-break-inside: avoid !important; page-break-after: avoid !important; break-after: avoid !important; }\n")
   cf:write("  .fullpage-layout-box { margin-top: 2px !important; margin-bottom: 0px !important; padding-top: 46px !important; padding-left: 8px !important; padding-right: 8px !important; padding-bottom: 6px !important; height: 90vh !important; max-height: 900px !important; box-sizing: border-box !important; page-break-inside: avoid !important; page-break-before: avoid !important; break-before: avoid !important; page-break-after: always !important; break-after: page !important; }\n")
   cf:write("  .fullpage-layout-box .boxcontainer { height: auto !important; max-height: calc(90vh - 50px) !important; box-sizing: border-box !important; }\n")
   cf:write("  .fullpage-layout-box .boxtitle { height: 20px !important; line-height: 20px !important; font-size: 13px !important; font-weight: bold !important; }\n")
   cf:write("  .fullpage-layout-box #vectorcenter { clear: both !important; margin: 0 auto !important; padding: 0 !important; width: 100% !important; }\n")
   cf:write("  .fullpage-layout-box #vectorcenter .level { min-height: 18px !important; height: 20px !important; line-height: 20px !important; padding: 2px 0 4px 0 !important; margin: 0 auto !important; font-size: 11px !important; text-align: center !important; }\n")
   cf:write("  .fullpage-layout-box svg { width: 98% !important; height: 80vh !important; max-height: 810px !important; margin: 2px auto 0 auto !important; display: block !important; }\n")
   cf:write("  .sheet-report-wrapper > .boxborder { margin: 8px 0 0px !important; padding-top: 40px !important; }\n")
   cf:write("  .sheet-report-wrapper .childboxborder { margin: 8px 0 0px !important; padding-top: 50px !important; }\n")
   cf:write("  .sheet-report-wrapper .boxcontainer { padding: 2px 6px !important; }\n")
   cf:write("  .sheet-report-wrapper .level { min-height: 18px !important; padding: 1px 0 !important; font-size: 11px !important; }\n")
   cf:write("  .sheet-report-wrapper .matcontainer { margin-bottom: 2px !important; }\n")
   cf:write("  #footer { display: none !important; visibility: hidden !important; height: 0 !important; margin: 0 !important; padding: 0 !important; }\n")
   cf:write("}\n")
   cf:write(".fullpage-layout-box svg { width: 98%; height: 80vh; max-height: 810px; margin: 2px auto 0; display: block; }\n")
   cf:write("#footer { display: none !important; visibility: hidden !important; height: 0 !important; margin: 0 !important; padding: 0 !important; }\n")
   cf:write("</style></head><body>\n")

   for idx, bpart in ipairs(combined_body_parts) do
      cf:write("<div class='sheet-report-wrapper'>\n")
      cf:write(bpart)
      cf:write("\n</div>\n")
   end

   cf:write("</body></html>\n")
   cf:close()

   -- Convert to single PDF using Edge
   local job_base_name = SanitizeFileName(job.Name, "Job")
   local pdf_filename = job_base_name .. "_Setup_Sheet.pdf"
   local pdf_out_path = g_options.postOutputFolder .. "\\" .. pdf_filename
   local temp_pdf_path = temp_dir .. "\\vectric_job_report_temp.pdf"

   -- Ensure stale files from previous exports cannot cause false-positive polling
   pcall(function() os.remove(temp_pdf_path) end)
   pcall(function() os.remove(pdf_out_path) end)

   LogMsg(dialog, "Converting to single PDF: " .. pdf_filename .. "...")

   local edge_path = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
   local bat_file = temp_dir .. "\\vectric_pdf_export.bat"
   local bf = io.open(bat_file, "wb")
   if bf ~= nil then
      bf:write('@echo off\r\n')
      bf:write('start /wait "" "' .. edge_path .. '" --headless --disable-gpu --run-all-compositor-stages-before-draw --print-to-pdf="' .. temp_pdf_path .. '" "' .. combined_html_path .. '"\r\n')
      bf:close()
      WriteDebugLog("Running Edge conversion batch file: " .. bat_file)
      os.execute('call "' .. bat_file .. '"')
      pcall(function() os.remove(bat_file) end)
   end

   -- Poll up to 25 seconds for Edge to finish writing the fresh local PDF
   local pdf_created = false
   for attempt = 1, 250 do
      local pf = io.open(temp_pdf_path, "rb")
      if pf ~= nil then
         local sz = pf:seek("end")
         pf:close()
         if sz > 2000 then
            pdf_created = true
            WriteDebugLog("Temp PDF verified created: " .. temp_pdf_path .. " (" .. tostring(sz) .. " bytes)")
            break
         end
      end
      local t0 = os.clock()
      while os.clock() - t0 < 0.1 do end
   end

   if pdf_created then
      -- Copy local temp PDF to final output destination
      local in_f = io.open(temp_pdf_path, "rb")
      if in_f ~= nil then
         local data = in_f:read("*a")
         in_f:close()
         local out_f = io.open(pdf_out_path, "wb")
         if out_f ~= nil then
            out_f:write(data)
            out_f:close()
            WriteDebugLog("PDF copied successfully to: " .. pdf_out_path .. " (" .. tostring(#data) .. " bytes)")
         else
            WriteDebugLog("❌ ERROR: Could not open output path for writing: " .. pdf_out_path)
            MessageBox("Could not write to destination file:\n" .. pdf_out_path .. "\n\nPlease check if the file is currently open in Adobe Acrobat or another viewer.")
         end
      end
      pcall(function() os.remove(temp_pdf_path) end)
      pcall(function() os.remove(combined_html_path) end)
      LogMsg(dialog, "\n========================================")
      LogMsg(dialog, "✔ Job Report PDF successfully exported to:\n" .. pdf_out_path)
      os.execute('start "" "' .. pdf_out_path .. '"')
   else
      WriteDebugLog("❌ ERROR: PDF creation timed out or failed for: " .. temp_pdf_path)
      LogMsg(dialog, "❌ PDF export failed. HTML retained at:\n" .. combined_html_path)
      MessageBox("PDF export failed. HTML file is available at:\n" .. combined_html_path)
   end

   SaveDefaults(g_options, job)
   return pdf_created
end

-- Button: Export Job Report (PDF)
function OnLuaButton_ExportJobReportButton(dialog)
   WriteDebugLog(">>> OnLuaButton_ExportJobReportButton clicked! <<<")
   local ok, res = pcall(function()
      return ExecuteExportJobReport(dialog, true)
   end)
   if not ok then
      WriteDebugLog("❌ Lua error in ExportJobReportButton: " .. tostring(res))
      LogMsg(dialog, "❌ Error: " .. tostring(res))
      MessageBox("Error during export:\n" .. tostring(res))
   end
   return true
end

-- Button 1: Apply to All Sheets
function OnLuaButton_ApplyOnlyButton(dialog)
   local job = VectricJob()
   if not job.Exists then 
      LogMsg(dialog, "❌ Error: No active job found.")
      MessageBox("No active job found.")
      return true 
   end
   ClearLog(dialog)

   local tp_mgr = ToolpathManager()
   ExecuteApplyToolpaths(dialog, job, tp_mgr, false, nil, "")
   SaveDefaults(g_options, job)
   return true
end

-- Button 2: Save Toolpaths Only (ATC)
function OnLuaButton_SaveOnlyButton(dialog)
   local job = VectricJob()
   if not job.Exists then 
      LogMsg(dialog, "❌ Error: No active job found.")
      MessageBox("No active job found.")
      return true 
   end
   UpdateOptionsFromDialog(dialog, g_options)
   ClearLog(dialog)

   if g_options.postOutputFolder == "" then
      LogMsg(dialog, "❌ Error: Please select an Output Folder first.")
      MessageBox("Please select an Output Folder first.")
      return true
   end

   local toolpath_saver = ToolpathSaver()
   local post = toolpath_saver:GetPostWithName(g_options.postName)
   if post == nil then
      LogMsg(dialog, "❌ Error: Failed to load post processor: " .. tostring(g_options.postName))
      MessageBox("Failed to load post processor: " .. tostring(g_options.postName))
      return true
   end

   ExecuteSaveToolpathsOnly(dialog, job, post, g_options.postOutputFolder)
   SaveDefaults(g_options, job)
   return true
end

-- Button 3: Apply & Save All in One Click
function OnLuaButton_ApplyAndSaveButton(dialog)
   local job = VectricJob()
   if not job.Exists then 
      LogMsg(dialog, "❌ Error: No active job found.")
      MessageBox("No active job found.")
      return true 
   end
   ClearLog(dialog)

   if g_options.postOutputFolder == "" then
      LogMsg(dialog, "❌ Error: Please select an Output Folder first.")
      MessageBox("Please select an Output Folder first.")
      return true
   end

   local toolpath_saver = ToolpathSaver()
   local post = toolpath_saver:GetPostWithName(g_options.postName)
   if post == nil then
      LogMsg(dialog, "❌ Error: Failed to load post processor: " .. tostring(g_options.postName))
      MessageBox("Failed to load post processor: " .. tostring(g_options.postName))
      return true
   end

   local tp_mgr = ToolpathManager()
   local ok = ExecuteApplyToolpaths(dialog, job, tp_mgr, true, post, g_options.postOutputFolder)
   if ok then
      LogMsg(dialog, "\n========================================")
      LogMsg(dialog, "Exporting Job Setup Report (PDF)...")
      ExecuteExportJobReport(dialog, false)
   end
   SaveDefaults(g_options, job)
   return true
end

function DisplayDialog(script_path, job)
   local script_html = "file:" .. script_path .. "\\Nested_Sheet_Assist.htm"
   local dialog = HTML_Dialog(false, script_html, g_options.windowWidth, g_options.windowHeight, g_title)

   if g_options.templatePath ~= "" then
      dialog:AddLabelField("TemplateFileNameLabel", g_options.templatePath)
   else
      dialog:AddLabelField("TemplateFileNameLabel", "(No template selected)")
   end

   dialog:AddCheckBox("UseActiveSheetCheck", g_options.useActiveSheet)
   dialog:AddCheckBox("OnlyVisibleToolpathsCheck", g_options.onlyVisibleToolpaths)
   dialog:AddTextField("PostOutputFolderEdit", g_options.postOutputFolder)
   dialog:AddDirectoryPicker("ChooseDirButton", "PostOutputFolderEdit", true)
   dialog:AddLabelField("GadgetVersion", g_version)
   dialog:AddTextField("StatusLogLabel", "Ready. Select template, apply toolpaths, or export Job Report PDF.")
   dialog:AddLabelField("StatusLogLabel", "Ready. Select template, apply toolpaths, or export Job Report PDF.")

   -- Collect all sheets in job to populate modal checklist
   local all_sheets_list = {}
   local sheet_mgr = job.SheetManager
   if sheet_mgr ~= nil then
      local s_ids = sheet_mgr:GetSheetIds()
      for s_id in s_ids do
         local s_name = sheet_mgr:GetSheetName(s_id)
         if s_name ~= nil and s_name ~= "" then
            table.insert(all_sheets_list, s_name)
         end
      end
   end
   if #all_sheets_list == 0 then
      table.insert(all_sheets_list, "Sheet 1")
   end
   local all_sheets_str = table.concat(all_sheets_list, "|")
   dialog:AddTextField("AllSheetsData", all_sheets_str)
   dialog:AddTextField("SelectedSheetsData", "ALL")

   PopulatePostDropDownList(dialog, "PostNameSelector", g_options.postName)

   dialog:ShowDialog()
   return true
end

function main(script_path)
   local job = VectricJob()
   if not job.Exists then
      MessageBox("Please open a job before running this gadget.")
      return false
   end

   LoadDefaults(g_options, job)
   DisplayDialog(script_path, job)
   return true
end
