/**
 * 商品素材库页面
 *
 * 功能：
 * 1. 分页展示所有商品素材
 * 2. 新建/编辑/删除素材
 * 3. 素材用于单品发布和批量发布
 */
import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { Plus, Pencil, Trash2, RefreshCw, Image, ChevronLeft, ChevronRight } from 'lucide-react'
import { useUIStore } from '@/store/uiStore'
import { useAuthStore } from '@/store/authStore'
import { getMaterials, deleteMaterial, type ProductMaterial } from '@/api/productPublish'
import { PageLoading } from '@/components/common/Loading'
import { ConfirmModal } from '@/components/common/ConfirmModal'
import { MaterialFormModal } from './MaterialFormModal'

export function ProductMaterials() {
  const { addToast } = useUIStore()
  const { user } = useAuthStore()
  const isAdmin = Boolean(user?.is_admin)
  const [loading, setLoading] = useState(true)
  const [tableLoading, setTableLoading] = useState(false)
  const [materials, setMaterials] = useState<ProductMaterial[]>([])
  const [total, setTotal] = useState(0)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(20)
  const [totalPages, setTotalPages] = useState(0)
  const [showModal, setShowModal] = useState(false)
  const [editTarget, setEditTarget] = useState<ProductMaterial | null>(null)
  const [deleteConfirm, setDeleteConfirm] = useState<{ open: boolean; item: ProductMaterial | null }>({ open: false, item: null })
  const [deleting, setDeleting] = useState(false)

  /** 加载素材列表 */
  const load = async (p = page, size = pageSize) => {
    setTableLoading(true)
    try {
      const res = await getMaterials(p, size)
      if (res.success) {
        setMaterials(res.data.list)
        setTotal(res.data.total)
        setTotalPages(res.data.total_pages)
      } else {
        addToast({ type: 'error', message: res.message || '加载失败' })
      }
    } catch {
      addToast({ type: 'error', message: '网络错误，请重试' })
    } finally {
      setLoading(false)
      setTableLoading(false)
    }
  }

  useEffect(() => { load(page, pageSize) }, [page, pageSize])

  /** 确认删除 */
  const handleConfirmDelete = async () => {
    if (!deleteConfirm.item) return
    setDeleting(true)
    try {
      const res = await deleteMaterial(deleteConfirm.item.id)
      if (res.success) {
        addToast({ type: 'success', message: '删除成功' })
        setDeleteConfirm({ open: false, item: null })
        load(page, pageSize)
      } else {
        addToast({ type: 'error', message: res.message || '删除失败' })
      }
    } catch {
      addToast({ type: 'error', message: '删除失败，请重试' })
    } finally {
      setDeleting(false)
    }
  }

  const handlePageSizeChange = (size: number) => { setPageSize(size); setPage(1) }

  if (loading) return <PageLoading />

  return (
    <div className="space-y-3 sm:space-y-4">
      {/* 标题栏 */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <div>
          <h1 className="page-title">商品素材库</h1>
          <p className="page-description">管理商品素材，用于单品发布和批量发布</p>
        </div>
        <div className="flex gap-2">
          <button className="btn-ios-secondary" onClick={() => load(page, pageSize)} disabled={tableLoading}>
            <RefreshCw className={`w-4 h-4 ${tableLoading ? 'animate-spin' : ''}`} />刷新
          </button>
          <button className="btn-ios-primary" onClick={() => { setEditTarget(null); setShowModal(true) }}>
            <Plus className="w-4 h-4" />新建素材
          </button>
        </div>
      </div>

      {/* 表格卡片 */}
      <motion.div
        initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}
        className="vben-card flex flex-col"
        style={{ height: 'calc(100vh - 210px)', minHeight: '400px' }}
      >
        <div className="vben-card-header">
          <h2 className="vben-card-title"><Image className="w-4 h-4" />素材列表</h2>
          <span className="badge-primary">共 {total} 条</span>
        </div>
        <div className="flex-1 overflow-x-auto overflow-y-auto">
          <table className="table-ios">
            <thead className="sticky top-0 bg-white dark:bg-slate-800 z-10">
              <tr>
                {isAdmin && <th>所属用户</th>}
                <th>标题</th>
                <th>价格</th>
                <th>分类</th>
                <th>成色</th>
                <th>图片</th>
                <th>创建时间</th>
                <th>操作</th>
              </tr>
            </thead>
            <tbody>
              {tableLoading ? (
                <tr><td colSpan={isAdmin ? 8 : 7} className="text-center py-12">
                  <RefreshCw className="w-6 h-6 animate-spin text-blue-500 mx-auto" />
                </td></tr>
              ) : materials.length === 0 ? (
                <tr><td colSpan={isAdmin ? 8 : 7} className="text-center py-12 text-slate-400">
                  <div className="flex flex-col items-center gap-2">
                    <Image className="w-12 h-12 text-slate-300" />
                    <p>暂无素材，点击「新建素材」添加</p>
                  </div>
                </td></tr>
              ) : materials.map(m => (
                <tr key={m.id}>
                  {isAdmin && (
                    <td className="text-sm text-slate-600 dark:text-slate-400 whitespace-nowrap">
                      {m.username || '-'}
                    </td>
                  )}
                  <td className="max-w-[200px]">
                    <span className="truncate block font-medium text-slate-800 dark:text-slate-100" title={m.title}>{m.title}</span>
                  </td>
                  <td>
                    <span className="text-amber-600 font-medium">{m.price}</span>
                    {m.original_price && (
                      <span className="text-xs text-slate-400 line-through ml-1">{m.original_price}</span>
                    )}
                  </td>
                  <td className="text-slate-500">{m.category || '-'}</td>
                  <td><span className="badge-gray">{m.condition}</span></td>
                  <td><span className="badge-info">{(m.images || []).length} 张</span></td>
                  <td className="text-sm text-slate-500 whitespace-nowrap">
                    {m.created_at ? new Date(m.created_at).toLocaleString('zh-CN', { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit' }) : '-'}
                  </td>
                  <td>
                    <div className="table-actions">
                      <button className="table-action-btn" title="编辑"
                        onClick={() => { setEditTarget(m); setShowModal(true) }}>
                        <Pencil className="w-4 h-4 text-blue-500" />
                      </button>
                      <button className="table-action-btn" title="删除"
                        onClick={() => setDeleteConfirm({ open: true, item: m })}>
                        <Trash2 className="w-4 h-4 text-red-500" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* 分页 */}
        {total > 0 && (
          <div className="flex-shrink-0 flex flex-col sm:flex-row items-center justify-between px-4 py-3 border-t border-slate-200 dark:border-slate-700 gap-3">
            <div className="flex items-center gap-2 text-sm text-slate-500">
              <span>每页</span>
              <select value={pageSize} onChange={e => handlePageSizeChange(Number(e.target.value))}
                className="px-2 py-1 border border-slate-300 dark:border-slate-600 rounded-md bg-white dark:bg-slate-800 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
                <option value={10}>10 条</option>
                <option value={20}>20 条</option>
                <option value={50}>50 条</option>
                <option value={100}>100 条</option>
              </select>
              <span>共 {total} 条</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-sm text-slate-500">第 {page} / {totalPages} 页</span>
              <button onClick={() => setPage(p => p - 1)} disabled={page <= 1 || tableLoading}
                className="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors">
                <ChevronLeft className="w-4 h-4" />
              </button>
              <button onClick={() => setPage(p => p + 1)} disabled={page >= totalPages || tableLoading}
                className="p-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors">
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </motion.div>

      {/* 新建/编辑弹窗 */}
      {showModal && (
        <MaterialFormModal
          initial={editTarget}
          onClose={() => setShowModal(false)}
          onSaved={() => { setShowModal(false); load(page, pageSize) }}
        />
      )}

      {/* 删除确认弹窗 */}
      <ConfirmModal
        isOpen={deleteConfirm.open}
        title="确认删除"
        message={`确认删除素材「${deleteConfirm.item?.title ?? ''}」？此操作不可撤销。`}
        confirmText="删除"
        type="danger"
        loading={deleting}
        onConfirm={handleConfirmDelete}
        onCancel={() => setDeleteConfirm({ open: false, item: null })}
      />
    </div>
  )
}

export default ProductMaterials