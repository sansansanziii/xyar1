import { get, put } from '@/utils/request'

const AUTO_RATE_PREFIX = '/api/v1/auto-rate'

// 自动评价配置类型
export interface AutoRateConfig {
  account_id: string
  enabled: boolean
  rate_type: 'text' | 'api'
  text_content?: string
  api_url?: string
}

// 获取自动评价配置
export const getAutoRateConfig = (accountId: string): Promise<{ success: boolean; data: AutoRateConfig }> => {
  return get(`${AUTO_RATE_PREFIX}/${accountId}`)
}

// 更新自动评价配置
export const updateAutoRateConfig = (
  accountId: string,
  config: Omit<AutoRateConfig, 'account_id'>
): Promise<{ success: boolean; message: string }> => {
  return put(`${AUTO_RATE_PREFIX}/${accountId}`, config)
}
