"use client";

import { useMemo } from 'react'
import {
  BarChart, Bar, LineChart, Line, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer
} from 'recharts'
import type { TableData } from '../stores/chatStore'

const COLORS = ['#29B5E8', '#71D3DC', '#FF9F36', '#8B5CF6', '#10B981', '#F59E0B']

interface SmartChartProps {
  table: TableData
  height?: number
}

type ChartType = 'bar' | 'line' | 'pie' | 'none'

function detectChartType(table: TableData): { 
  type: ChartType
  labelColumn: string
  valueColumns: string[]
  data: Record<string, unknown>[] 
} {
  try {
    const { columns, rows } = table
    
    if (!columns?.length || columns.length < 2 || !rows?.length) {
      return { type: 'none', labelColumn: '', valueColumns: [], data: [] }
    }

    const data = rows.map(row => {
      const obj: Record<string, unknown> = {}
      columns.forEach((col, i) => {
        const value = row[i]
        obj[col] = typeof value === 'string' && !isNaN(Number(value)) ? Number(value) : value
      })
      return obj
    })

    const columnTypes = columns.map((col, i) => {
      const numericCount = rows.filter(r => typeof r[i] === 'number' || !isNaN(Number(r[i]))).length
      return { name: col, isNumeric: numericCount > rows.length * 0.7 }
    })

    const labelColumn = columnTypes.find(c => !c.isNumeric)?.name || columns[0]
    const valueColumns = columnTypes.filter(c => c.isNumeric && c.name !== labelColumn).map(c => c.name)

    if (!valueColumns.length) return { type: 'none', labelColumn: '', valueColumns: [], data: [] }

    let type: ChartType = 'bar'
    
    if (valueColumns.length === 1 && rows.length <= 6) type = 'pie'
    
    const labelLower = labelColumn.toLowerCase()
    if (['date', 'time', 'month', 'year', 'quarter', 'week'].some(k => labelLower.includes(k))) {
      type = 'line'
    }

    return { type, labelColumn, valueColumns, data }
  } catch {
    return { type: 'none', labelColumn: '', valueColumns: [], data: [] }
  }
}

export default function SmartChart({ table, height = 300 }: SmartChartProps) {
  const config = useMemo(() => detectChartType(table), [table])

  if (config.type === 'none' || !config.data.length) {
    return <div className="p-4 text-center text-slate-500">Unable to render chart</div>
  }

  const { type, labelColumn, valueColumns, data } = config
  const formatValue = (v: number) => v >= 1e6 ? `${(v/1e6).toFixed(1)}M` : v >= 1e3 ? `${(v/1e3).toFixed(1)}K` : v.toFixed(0)
  const commonProps = { data, margin: { top: 20, right: 30, left: 20, bottom: 60 } }

  return (
    <div className="p-4 bg-slate-50 rounded-lg border border-slate-200">
      <ResponsiveContainer width="100%" height={height}>
        {type === 'pie' ? (
          <PieChart>
            <Pie 
              data={data} 
              dataKey={valueColumns[0]} 
              nameKey={labelColumn} 
              cx="50%" 
              cy="50%" 
              outerRadius={100}
              label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
            >
              {data.map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
            </Pie>
            <Tooltip formatter={(v: number) => formatValue(v)} />
            <Legend />
          </PieChart>
        ) : type === 'line' ? (
          <LineChart {...commonProps}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
            <XAxis dataKey={labelColumn} tick={{ fill: '#64748b', fontSize: 12 }} angle={-45} textAnchor="end" />
            <YAxis tick={{ fill: '#64748b' }} tickFormatter={formatValue} />
            <Tooltip formatter={(v: number) => formatValue(v)} />
            <Legend />
            {valueColumns.map((col, i) => (
              <Line key={col} type="monotone" dataKey={col} stroke={COLORS[i % COLORS.length]} strokeWidth={2} />
            ))}
          </LineChart>
        ) : (
          <BarChart {...commonProps}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e2e8f0" />
            <XAxis dataKey={labelColumn} tick={{ fill: '#64748b', fontSize: 12 }} angle={-45} textAnchor="end" />
            <YAxis tick={{ fill: '#64748b' }} tickFormatter={formatValue} />
            <Tooltip formatter={(v: number) => formatValue(v)} />
            <Legend />
            {valueColumns.map((col, i) => (
              <Bar key={col} dataKey={col} fill={COLORS[i % COLORS.length]} radius={[4, 4, 0, 0]} />
            ))}
          </BarChart>
        )}
      </ResponsiveContainer>
    </div>
  )
}
