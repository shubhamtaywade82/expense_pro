import { useState, useRef, useEffect } from "react";
import { useMutation } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Sparkles, User, Send, Trash2, ArrowRight } from "lucide-react";
import { toast } from "sonner";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

type ChatMessage = {
  role: "user" | "assistant";
  content: string;
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
      content: "Hello! I am your ExpensePro AI Financial Assistant. Ask me questions about your monthly savings, upcoming bills, categories, or type something like: *'Spent 300 on groceries paid via cash'* to log an expense automatically!"
    }
  ]);
  const [input, setInput] = useState("");
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const chatMutation = useMutation({
    mutationFn: api.ai.chat,
    onSuccess: (data) => {
      setMessages((prev) => [...prev, { role: "assistant", content: data.content || "I'm sorry, I couldn't process that request." }]);
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to get response from AI");
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: "Sorry, I encountered an error connecting to my server. Please verify Ollama is running." }
      ]);
    }
  });

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, chatMutation.isPending]);

  const handleSend = (text: string) => {
    if (!text.trim() || chatMutation.isPending) return;

    const userMessage: ChatMessage = { role: "user", content: text };
    const history = messages.slice(1);

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
        content: "Chat history cleared. How can I help you manage your finances now?"
      }
    ]);
    toast.success("Chat history cleared");
  };

  return (
    <div className="flex flex-col h-full max-w-4xl mx-auto space-y-4 animate-stagger-fade" style={{ animationDelay: "0ms" }}>
      <div className="flex-shrink-0 flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold font-display tracking-tight flex items-center gap-2 text-foreground">
            <Sparkles className="w-6 h-6 text-primary animate-pulse filter drop-shadow-[0_0_8px_rgba(99,102,241,0.5)]" />
            AI Financial Assistant
          </h2>
          <p className="text-sm text-muted-foreground font-sans">Ask questions, parse sentences to log ledger updates, and analyze metrics</p>
        </div>
        <Button variant="outline" size="sm" onClick={handleClear} disabled={messages.length <= 1} className="rounded-xl border-border/60 text-muted-foreground hover:text-red-500 hover:bg-red-500/5 transition-all">
          <Trash2 className="w-4 h-4 mr-1.5" /> Clear History
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 flex-1 min-h-0 overflow-hidden">
        {/* Chat History Panel */}
        <div className="md:col-span-3 flex flex-col h-full overflow-hidden glass-card glowing-border rounded-2xl">
          <div className="py-3.5 px-4 border-b border-border/40 bg-card/40 flex items-center justify-between">
            <div className="text-xs font-bold font-display text-muted-foreground flex items-center gap-2">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
              </span>
              ExpenseFlow Intellect AI
            </div>
            <span className="text-[10px] bg-primary/10 text-primary font-semibold px-2 py-0.5 rounded-full border border-primary/10 font-display">v1.2-Ollama</span>
          </div>
          <div className="flex-1 overflow-y-auto p-4 space-y-4 min-h-0 bg-transparent">
            {messages.map((msg, index) => (
              <div
                key={index}
                className={`flex gap-3 max-w-[85%] ${msg.role === "user" ? "ml-auto flex-row-reverse" : "mr-auto"}`}
              >
                <div
                  className={`w-10 h-10 rounded-xl flex items-center justify-center text-white flex-shrink-0 shadow-md ${
                    msg.role === "user" 
                      ? "bg-gradient-to-tr from-primary to-indigo-600" 
                      : "bg-gradient-to-tr from-emerald-500 to-teal-600"
                  }`}
                >
                  {msg.role === "user" ? <User className="w-5 h-5" /> : <Sparkles className="w-5 h-5" />}
                </div>
                <div
                  className={`p-3.5 rounded-2xl shadow-sm text-sm leading-relaxed prose prose-sm dark:prose-invert max-w-none ${
                    msg.role === "user"
                      ? "bg-primary text-primary-foreground rounded-tr-none font-medium prose-headings:text-primary-foreground prose-p:text-primary-foreground prose-strong:text-primary-foreground"
                      : "bg-card/75 backdrop-blur-md border border-border/50 rounded-tl-none text-foreground"
                  }`}
                >
                  <ReactMarkdown remarkPlugins={[remarkGfm]}>
                    {msg.content}
                  </ReactMarkdown>
                </div>
              </div>
            ))}

            {chatMutation.isPending && (
              <div className="flex gap-3 max-w-[80%] mr-auto items-center">
                <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-emerald-500 to-teal-600 flex items-center justify-center text-white flex-shrink-0 shadow-sm">
                  <Sparkles className="w-5 h-5 animate-spin" />
                </div>
                <div className="bg-card/75 backdrop-blur-md border border-border/50 p-3.5 rounded-2xl rounded-tl-none shadow-sm flex items-center gap-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-primary/40 animate-bounce" style={{ animationDelay: "0ms" }} />
                  <span className="w-2.5 h-2.5 rounded-full bg-primary/40 animate-bounce" style={{ animationDelay: "150ms" }} />
                  <span className="w-2.5 h-2.5 rounded-full bg-primary/40 animate-bounce" style={{ animationDelay: "300ms" }} />
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </div>

          {/* Chat Input form */}
          <div className="p-3.5 border-t border-border/40 bg-card/25 backdrop-blur-md">
            <form
              onSubmit={(e) => {
                e.preventDefault();
                handleSend(input);
              }}
              className="flex gap-2"
            >
              <Input
                value={input}
                onChange={(e) => setInput(e.target.value)}
                placeholder="Ask financial advice or type 'spent 500 on dinner paid via upi'..."
                className="flex-1 text-sm bg-background/50 rounded-xl border-border/50 focus-visible:ring-primary h-10"
                disabled={chatMutation.isPending}
              />
              <Button type="submit" disabled={chatMutation.isPending || !input.trim()} className="rounded-xl h-10 px-4 bg-primary hover:bg-primary/90 text-white shadow-md shadow-primary/15 transition-all">
                <Send className="w-5 h-5" />
              </Button>
            </form>
          </div>
        </div>

        {/* Sidebar suggestions */}
        <div className="space-y-4">
          <div className="glass-card glowing-border rounded-2xl p-4">
            <span className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground block mb-1 font-display">
              Suggested Prompts
            </span>
            <span className="text-[11px] text-muted-foreground font-sans block mb-3">Click on a prompt to execute:</span>
            <div className="space-y-2">
              {SUGGESTIONS.map((suggestion, idx) => (
                <button
                  key={idx}
                  onClick={() => handleSend(suggestion)}
                  disabled={chatMutation.isPending}
                  className="w-full text-left text-xs p-3 rounded-xl bg-card/25 border border-border/40 hover:border-primary/40 text-muted-foreground hover:text-primary transition-all duration-300 flex items-center justify-between group"
                >
                  <span className="line-clamp-2 pr-2 font-medium font-sans">{suggestion}</span>
                  <ArrowRight className="w-3.5 h-3.5 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0 text-primary" />
                </button>
              ))}
            </div>
          </div>

          <div className="glass-card glowing-border rounded-2xl p-4 bg-gradient-to-tr from-primary/5 to-indigo-500/5">
            <h4 className="text-xs font-bold text-primary flex items-center gap-1.5 font-display mb-2">
              <Sparkles className="w-3.5 h-3.5" />
              Natural Language Parsing
            </h4>
            <p className="text-[11px] text-muted-foreground leading-relaxed font-sans">
              Try typing:
              <br />
              <span className="font-semibold text-foreground italic">"Logged 2000 for Internet bill using UPI"</span>
              <br />
              The assistant resolves parameters (amount, category, payment method) and issues transaction entries dynamically!
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
