local http = require 'resty.http'
local json = json or require 'cjson'
local i  = require 'inspect'
local _M = { __VERSION = '0.1-0' }
local mt = { __index = _M }

local sandbox_url = 'https://api.sandbox.paypal.com/v1/'
local api_url = 'https://api.paypal.com/v1/'

function _M.new(config)
  if not config then error("Missing paypal config params") end
  if not config.client_id then error("Missing required paypal client_id") end
  if not config.secret then error("Missing require paypal secret") end

  _M.env = config.env or 'sandbox'
  _M.client_id = config.client_id
  _M.secret = config.secret
  return setmetatable(_M, mt)
end

function _M.request(self, method, path, params)
  local httpc = http.new()
  local access_token, err = self:get_access_token() 
  local args  = {
    method = method,
    body = json.encode(params),
    ssl_verify = false,
    headers = {
      ['Content-Type']  = 'application/json',
      ['Authorization'] =  'Bearer ' .. access_token
    } 
  }
  local url = self:create_url(path)
  local res, err = httpc:request_uri(url, args)
  ngx.log(ngx.ERR, "paypal api request " .. url)
  if res.status == 201 or res.status == 200 then
    return json.decode(res.body) 
  else
    return nil, json.decode(res.body)
  end
end

function _M.create_url(self, path, params)
  local api = self.env == 'sandbox' and sandbox_url or api_url
  local url = api .. path
  if params then url = url .. '?' .. ngx.encode_args(params or {}) end
  return url
end

function _M.get_access_token(self)
  local httpc = http.new()
  local args = {
    method = 'POST',
    body = "grant_type=client_credentials",
    ssl_verify = false,
    headers = { 
      ['Accept'] = 'application/json',
      ['Authorization'] = 'Basic ' .. ngx.encode_base64(_M.client_id .. ':' .. _M.secret)
    }
  } 
  local url = self:create_url('oauth2/token')
  local res, err = httpc:request_uri(url, args) 
  if not res then return nil, err end
  if res.status == 200 then
    local body = json.decode(res.body)
    return body.access_token
  end 
end

function _M.get(self, api, args)
  return self:request('GET', api, args) 
end

function _M.post(self, api, args)
  return self:request('POST', api, args) 
end

function _M.put(self, api, args)
  return self:request('PUT', api, args) 
end

function _M.patch(self, api, args)
  return self:request('PATCH', api, args) 
end

function _M.delete(self, api, args)
  return self:request('DELETE', api, args) 
end

return _M
