---@meta
-- Central type definitions for nohands.nvim

---@class NoHandsOpenRouterOptions
---@field base_url string
---@field api_key_env string
---@field referer? string
---@field title? string

---@class NoHandsOutputOptions
---@field method 'split'|'append'|'replace'|'float'|'diff'
---@field split_direction 'below'|'right'

---@class NoHandsPickerOptions
---@field session_first boolean

---@class NoHandsKeysOptions
---@field nohands? string
---@field run? string
---@field stream? string
---@field refactor? string
---@field palette? string

---@class NoHandsPromptTemplate
---@field name string
---@field system? string
---@field user string
---@field transform? fun(content:string, ctx:table):string
---@field tags? string[]
---@field model? string
---@field temperature? number
---@field max_tokens? integer

---@class NoHandsUsageOptions
---@field notify boolean

---@class NoHandsConfig
---@field model string
---@field temperature number
---@field max_tokens integer
---@field openrouter NoHandsOpenRouterOptions
---@field prompts table<string, NoHandsPromptTemplate>
---@field output NoHandsOutputOptions
---@field picker NoHandsPickerOptions
---@field keys? NoHandsKeysOptions
---@field stream table
---@field diff table
---@field models table
---@field retry table
---@field usage NoHandsUsageOptions

---@class NoHandsRunOptions
---@field prompt? string
---@field source? 'buffer'|'selection'|'surrounding'|'diff'|'lsp_symbol'|'diagnostic'|'quickfix'|'range'
---@field before? integer
---@field after? integer
---@field model? string
---@field output? 'split'|'append'|'replace'|'float'|'diff'
---@field temperature? number
---@field max_tokens? integer
---@field stream? boolean
---@field session? string
---@field stateless? boolean

---@class NoHandsContentMetaBuffer
---@field type 'buffer'
---@field bufnr integer
---@field path string

---@class NoHandsContentMetaSelection
---@field type 'selection'
---@field range { start_line: integer, end_line: integer }

---@class NoHandsContentMetaSurrounding
---@field type 'surrounding'
---@field center integer
---@field before integer
---@field after integer

---@class NoHandsContentMetaRange
---@field type 'range'
---@field start_line integer
---@field end_line integer

---@class NoHandsContentMetaDiagnostic
---@field type 'diagnostic'
---@field bufnr integer
---@field line integer

---@class NoHandsContentMetaQuickfix
---@field type 'quickfix'

---@alias NoHandsContentMeta
---| NoHandsContentMetaBuffer
---| NoHandsContentMetaSelection
---| NoHandsContentMetaSurrounding
---| NoHandsContentMetaRange
---| NoHandsContentMetaDiagnostic
---| NoHandsContentMetaQuickfix

---@class NoHandsContent
---@field text string
---@field meta NoHandsContentMeta

---@class NoHandsSession
---@field id string
---@field messages table[]

return {}
