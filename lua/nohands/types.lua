---@meta
-- Central type definitions for nohands.nvim

---@class NoHandsOpenRouterOptions
---@field base_url string
---@field api_key_env string
---@field referer? string
---@field title? string

---@class NoHandsOutputOptions
---@field method 'split'|'append'|'replace'|'float'
---@field split_direction 'below'|'right'

---@class NoHandsPickerOptions
---@field use_snacks boolean
---@field session_first boolean

---@class NoHandsPromptTemplate
---@field name string
---@field system? string
---@field user string
---@field transform? fun(content:string, ctx:table):string

---@class NoHandsIndicatorOptions
---@field enabled boolean

---@class NoHandsConfig
---@field model string
---@field temperature number
---@field max_tokens integer
---@field openrouter NoHandsOpenRouterOptions
---@field prompts table<string, NoHandsPromptTemplate>
---@field output NoHandsOutputOptions
---@field picker NoHandsPickerOptions
---@field stream table
---@field diff table
---@field models table
---@field retry table
---@field indicator NoHandsIndicatorOptions

---@class NoHandsRunOptions
---@field prompt? string
---@field source? 'buffer'|'selection'|'surrounding'|'diff'
---@field before? integer
---@field after? integer
---@field model? string
---@field output? 'split'|'append'|'replace'|'float'
---@field temperature? number
---@field max_tokens? integer
---@field stream? boolean
---@field session? string

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

---@alias NoHandsContentMeta NoHandsContentMetaBuffer|NoHandsContentMetaSelection|NoHandsContentMetaSurrounding|NoHandsContentMetaRange -- luacheck: ignore max_line_length

---@class NoHandsContent
---@field text string
---@field meta NoHandsContentMeta

---@class NoHandsSession
---@field id string
---@field messages table[]

return {}
