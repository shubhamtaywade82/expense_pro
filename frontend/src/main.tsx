import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router'
import './index.css'
import { AppQueryProvider } from "@/providers/query-client"
import { Toaster } from "@/components/ui/sonner"
import App from './App.tsx'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <BrowserRouter>
      <AppQueryProvider>
        <App />
        <Toaster />
      </AppQueryProvider>
    </BrowserRouter>
  </StrictMode>,
)
