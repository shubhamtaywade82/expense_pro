import { useState, useRef, useEffect, useMemo } from "react";
import { useMutation } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { 
  Sparkles, 
  User, 
  Send, 
  Trash2, 
  ArrowRight, 
  Copy, 
  Check, 
  MoreHorizontal, 
  MessageSquare,
  Zap,
  Info
} from "lucide-react";
import { toast } from "sonner";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { format } from "date-fns";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { cn } from "@/lib/utils";

type ChatMessage = {
  role: "user" | "assistant";
  content: string;
  timestamp: Date;
};

const SUGGESTIONS = [
  "How are my savings doing this month?",
  "Log an expense: 450 on dining out paid via upi today.",
  "What is my total net balance to date?",
  "What is the status of my Rent bill?"
];

export default function AiAssistant() {
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      role: "assistant",
      content: "Hello! I am your ExpensePro AI Financial Assistant. Ask me questions about your monthly savings, upcoming bills, categories, or type something like: *'Spent 300 on groceries paid via cash'* to log an expense automatically!",
      timestamp: new Date()
    }
  ]);
  const [input, setInput] = useState("");
  const [copiedIndex, setCopiedIndex] = useState<number | null>(null);
  const messagesContainerRef = useRef<HTMLDivElement>(null);

  const chatMutation = useMutation({
    mutationFn: api.ai.chat,
    onSuccess: (data) => {
      setMessages((prev) => [...prev, { 
        role: "assistant", 
        content: data.content || "I'm sorry, I couldn't process that request.",
        timestamp: new Date()
      }]);
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to get response from AI");
      setMessages((prev) => [
        ...prev,
        { 
          role: "assistant", 
          content: "Sorry, I encountered an error connecting to my server. Please verify Ollama is running.",
          timestamp: new Date()
        }
      ]);
    }
  });

  const scrollToBottom = () => {
    if (messagesContainerRef.current) {
      messagesContainerRef.current.scrollTo({
        top: messagesContainerRef.current.scrollHeight,
        behavior: "smooth"
      });
    }
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, chatMutation.isPending]);

  const handleSend = (text: string) => {
    if (!text.trim() || chatMutation.isPending) return;

    const userMessage: ChatMessage = { role: "user", content: text, timestamp: new Date() };
    const history = messages.slice(1).map(m => ({ role: m.role, content: m.content }));

    setMessages((prev) => [...prev, userMessage]);
    setInput("");

    chatMutation.mutate({
      message: text,
      history: history
    });
  };

  const handleClear = () => {
    setMessages([
      {
        role: "assistant",
        content: "Chat history cleared. How can I help you manage your finances now?",
        timestamp: new Date()
      }
    ]);
    toast.success("Chat history cleared");
  };

  const copyToClipboard = (text: string, index: number) => {
    navigator.clipboard.writeText(text);
    setCopiedIndex(index);
    toast.success("Copied to clipboard");
    setTimeout(() => setCopiedIndex(null), 2000);
  };

  return (
    <div className="flex flex-col flex-1 min-h-0 max-w-5xl mx-auto space-y-4 animate-stagger-fade w-full" style={{ animationDelay: "0ms" }}>
      <div className="flex-shrink-0 flex items-center justify-between px-1">
        <div className="flex items-center gap-3">
          <div className="w-12 h-12 rounded-2xl bg-primary/10 flex items-center justify-center border border-primary/20 shadow-sm">
            <Zap className="w-6 h-6 text-primary filter drop-shadow-[0_0_8px_rgba(99,102,241,0.4)]" />
          </div>
          <div>
            <h2 className="text-2xl font-black font-display tracking-tight text-foreground flex items-center gap-2">
              Expense Intellect
              <Badge variant="outline" className="text-[10px] font-black uppercase tracking-widest bg-emerald-500/5 text-emerald-600 border-emerald-500/10">Active</Badge>
            </h2>
            <p className="text-xs text-muted-foreground font-medium">Hyper-personalized financial assistance powered by AI</p>
          </div>
        </div>
        <Button variant="ghost" size="sm" onClick={handleClear} disabled={messages.length <= 1} className="rounded-xl border border-border/40 text-muted-foreground hover:text-red-500 hover:bg-red-500/5 transition-all h-9">
          <Trash2 className="w-4 h-4 mr-1.5" /> Clear
        </Button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-4 gap-6 flex-1 min-h-0 overflow-hidden">
        {/* Chat History Panel */}
        <div className="lg:col-span-3 flex flex-col h-full overflow-hidden glass-card glowing-border rounded-[32px] border-border/40 bg-card/30 backdrop-blur-3xl shadow-2xl">
          <div className="py-4 px-6 border-b border-border/40 bg-card/40 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="relative flex h-3 w-3">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-3 w-3 bg-emerald-500 border-2 border-background"></span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs font-black font-display text-foreground uppercase tracking-wider">Ollama v1.2 Engine</span>
                <span className="text-[10px] text-muted-foreground font-bold">Latency: ~240ms • Secure Context</span>
              </div>
            </div>
            <div className="flex items-center gap-2">
               <Button variant="ghost" size="icon" className="h-8 w-8 rounded-lg text-muted-foreground"><Info className="w-4 h-4" /></Button>
               <Button variant="ghost" size="icon" className="h-8 w-8 rounded-lg text-muted-foreground"><MoreHorizontal className="w-4 h-4" /></Button>
            </div>
          </div>
          
          <div 
            ref={messagesContainerRef}
            className="flex-1 overflow-y-auto p-6 space-y-8 min-h-0 bg-transparent scroll-smooth custom-scrollbar"
          >
            {messages.map((msg, index) => (
              <div
                key={index}
                className={cn(
                  "flex gap-4 group animate-in fade-in slide-in-from-bottom-2 duration-300",
                  msg.role === "user" ? "flex-row-reverse" : "flex-row"
                )}
              >
                <div
                  className={cn(
                    "w-10 h-10 rounded-2xl flex items-center justify-center text-white flex-shrink-0 shadow-lg transition-transform group-hover:scale-105",
                    msg.role === "user" 
                      ? "bg-gradient-to-tr from-primary to-indigo-600 ring-4 ring-primary/10" 
                      : "bg-gradient-to-tr from-emerald-500 to-teal-600 ring-4 ring-emerald-500/10"
                  )}
                >
                  {msg.role === "user" ? <User className="w-5 h-5" /> : <Sparkles className="w-5 h-5" />}
                </div>
                
                <div className={cn("flex flex-col space-y-1.5 max-w-[85%]", msg.role === "user" ? "items-end" : "items-start")}>
                  <div
                    className={cn(
                      "p-4 rounded-[24px] shadow-sm text-sm leading-relaxed prose prose-sm dark:prose-invert max-w-none relative group/bubble",
                      msg.role === "user"
                        ? "bg-primary text-primary-foreground rounded-tr-none font-medium prose-headings:text-primary-foreground prose-p:text-primary-foreground prose-strong:text-primary-foreground shadow-primary/20"
                        : "bg-card/80 backdrop-blur-xl border border-border/50 rounded-tl-none text-foreground shadow-black/5"
                    )}
                  >
                    <ReactMarkdown remarkPlugins={[remarkGfm]}>
                      {msg.content}
                    </ReactMarkdown>

                    {msg.role === "assistant" && (
                      <button 
                        onClick={() => copyToClipboard(msg.content, index)}
                        className="absolute -right-10 top-0 p-2 rounded-lg bg-card/50 border border-border/40 opacity-0 group-hover/bubble:opacity-100 transition-all hover:bg-primary/10 hover:text-primary active:scale-90"
                        title="Copy to clipboard"
                      >
                        {copiedIndex === index ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
                      </button>
                    )}
                  </div>
                  <span className="text-[10px] font-bold text-muted-foreground/60 px-1 uppercase tracking-tighter">
                    {format(msg.timestamp, "hh:mm aa")} • {msg.role === "user" ? "Me" : "Assistant"}
                  </span>
                </div>
              </div>
            ))}

            {chatMutation.isPending && (
              <div className="flex gap-4 animate-in fade-in duration-300">
                <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-emerald-500 to-teal-600 flex items-center justify-center text-white flex-shrink-0 shadow-lg ring-4 ring-emerald-500/10">
                  <Sparkles className="w-5 h-5 animate-pulse" />
                </div>
                <div className="bg-card/80 backdrop-blur-xl border border-border/50 p-4 rounded-[24px] rounded-tl-none shadow-sm flex items-center gap-2">
                  <div className="flex gap-1.5">
                    <span className="w-2 h-2 rounded-full bg-primary/40 animate-bounce [animation-delay:-0.3s]" />
                    <span className="w-2 h-2 rounded-full bg-primary/40 animate-bounce [animation-delay:-0.15s]" />
                    <span className="w-2 h-2 rounded-full bg-primary/40 animate-bounce" />
                  </div>
                  <span className="text-xs font-black text-muted-foreground/60 uppercase tracking-widest ml-2">Thinking...</span>
                </div>
              </div>
            )}
          </div>

          {/* Chat Input form */}
          <div className="p-6 border-t border-border/40 bg-card/30 backdrop-blur-3xl">
            <form
              onSubmit={(e) => {
                e.preventDefault();
                handleSend(input);
              }}
              className="relative group"
            >
              <Input
                value={input}
                onChange={(e) => setInput(e.target.value)}
                placeholder="Ask financial advice or type 'spent 500 on dinner paid via upi'..."
                className="w-full h-14 pl-5 pr-16 text-sm bg-background/60 rounded-[20px] border-border/50 focus-visible:ring-primary shadow-inner transition-all group-focus-within:bg-background group-focus-within:border-primary/30"
                disabled={chatMutation.isPending}
              />
              <div className="absolute right-2 top-2">
                <Button 
                  type="submit" 
                  disabled={chatMutation.isPending || !input.trim()} 
                  className="rounded-[14px] h-10 w-10 p-0 bg-primary hover:bg-primary/90 text-white shadow-lg shadow-primary/30 transition-all active:scale-95"
                >
                  <Send className="w-5 h-5" />
                </Button>
              </div>
            </form>
            <p className="text-[10px] text-center mt-3 text-muted-foreground font-bold uppercase tracking-widest opacity-60">
              Press <kbd className="bg-muted px-1.5 py-0.5 rounded border border-border/60">Enter</kbd> to submit • AI may occasionally hallucinate data
            </p>
          </div>
        </div>

        {/* Sidebar suggestions */}
        <div className="space-y-6 flex flex-col h-full overflow-y-auto pr-1 -mr-1 custom-scrollbar">
          <div className="glass-card glowing-border rounded-[28px] p-6 shadow-sm border-border/40">
            <div className="flex items-center gap-2 mb-4">
              <MessageSquare className="w-4 h-4 text-primary" />
              <span className="text-[10px] font-black uppercase tracking-widest text-foreground">
                Suggested Prompts
              </span>
            </div>
            <div className="space-y-3">
              {SUGGESTIONS.map((suggestion, idx) => (
                <button
                  key={idx}
                  onClick={() => handleSend(suggestion)}
                  disabled={chatMutation.isPending}
                  className="w-full text-left text-xs p-4 rounded-2xl bg-card/40 border border-border/50 hover:border-primary/50 hover:bg-primary/5 text-muted-foreground hover:text-primary transition-all duration-300 flex items-center justify-between group shadow-sm"
                >
                  <span className="line-clamp-2 pr-2 font-bold leading-relaxed">{suggestion}</span>
                  <ArrowRight className="w-3.5 h-3.5 opacity-0 -translate-x-2 group-hover:opacity-100 group-hover:translate-x-0 transition-all flex-shrink-0" />
                </button>
              ))}
            </div>
          </div>

          <div className="glass-card glowing-border rounded-[28px] p-6 bg-gradient-to-tr from-primary/10 to-indigo-500/10 border-primary/20 shadow-lg flex-1">
            <div className="w-10 h-10 rounded-xl bg-primary/20 flex items-center justify-center mb-4">
              <Zap className="w-5 h-5 text-primary" />
            </div>
            <h4 className="text-xs font-black text-foreground uppercase tracking-widest mb-3">
              Smart Processing
            </h4>
            <p className="text-[11px] text-muted-foreground leading-relaxed font-bold italic border-l-2 border-primary/30 pl-3">
              "Spent 2000 for Internet bill using UPI"
            </p>
            <p className="text-[11px] text-muted-foreground mt-4 leading-relaxed font-medium">
              Our engine automatically resolves parameters and logs ledger entries in real-time. No manual forms needed.
            </p>
            
            <div className="mt-6 pt-6 border-t border-primary/10">
              <div className="flex items-center gap-2 mb-2">
                <div className="w-1.5 h-1.5 rounded-full bg-emerald-500" />
                <span className="text-[9px] font-black uppercase tracking-widest text-muted-foreground">Self-Learning Mode</span>
              </div>
              <Progress value={78} className="h-1 bg-primary/10" />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
