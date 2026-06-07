import { useState, useRef, useEffect } from "react";
import { useMutation } from "@tanstack/react-query";
import { api } from "@/lib/api";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Sparkles, User, Send, Trash2, ArrowRight } from "lucide-react";
import { toast } from "sonner";

type ChatMessage = {
  role: "user" | "assistant";
  content: string;
};

const SUGGESTIONS = [
  "Give me a summary of my net savings this month.",
  "Log an expense: 450 on dining out paid via upi today.",
  "What are my upcoming bills?",
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
      setMessages((prev) => [...prev, { role: "assistant", content: data.content }]);
    },
    onError: (error: any) => {
      toast.error(error.message || "Failed to get response from AI");
      // Remove last user message if it failed, or keep it and add an error notice
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
    const history = messages.slice(1); // Exclude the initial welcome message to keep context clean

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
    <div className="flex flex-col h-[calc(100vh-10rem)] max-w-4xl mx-auto space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight flex items-center gap-2">
            <Sparkles className="w-6 h-6 text-indigo-500 animate-pulse" />
            AI Financial Assistant
          </h2>
          <p className="text-muted-foreground">Ask questions, log transactions, and get financial insights.</p>
        </div>
        <Button variant="outline" size="sm" onClick={handleClear} disabled={messages.length <= 1}>
          <Trash2 className="w-4 h-4 mr-1 text-red-500" /> Clear Chat
        </Button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4 flex-1 min-h-0">
        {/* Chat History Panel */}
        <Card className="md:col-span-3 flex flex-col h-full overflow-hidden border border-muted/80 shadow-lg">
          <CardHeader className="py-3 px-4 border-b bg-muted/20">
            <CardTitle className="text-sm font-semibold flex items-center gap-2">
              <span className="w-2.5 h-2.5 rounded-full bg-green-500 animate-ping" />
              ExpensePro AI Chatbot
            </CardTitle>
          </CardHeader>
          <CardContent className="flex-1 overflow-y-auto p-4 space-y-4 min-h-0 bg-gradient-to-b from-transparent to-muted/10">
            {messages.map((msg, index) => (
              <div
                key={index}
                className={`flex gap-3 max-w-[85%] ${msg.role === "user" ? "ml-auto flex-row-reverse" : "mr-auto"}`}
              >
                <div
                  className={`w-8 h-8 rounded-full flex items-center justify-center text-white flex-shrink-0 ${
                    msg.role === "user" ? "bg-indigo-600" : "bg-teal-600"
                  }`}
                >
                  {msg.role === "user" ? <User className="w-4 h-4" /> : <Sparkles className="w-4 h-4" />}
                </div>
                <div
                  className={`p-3 rounded-2xl shadow-sm text-sm leading-relaxed ${
                    msg.role === "user"
                      ? "bg-indigo-600 text-white rounded-tr-none"
                      : "bg-card border border-muted rounded-tl-none text-foreground"
                  }`}
                >
                  {msg.content.split("\n").map((line, lIdx) => (
                    <p key={lIdx} className={lIdx > 0 ? "mt-2" : ""}>
                      {line}
                    </p>
                  ))}
                </div>
              </div>
            ))}

            {chatMutation.isPending && (
              <div className="flex gap-3 max-w-[80%] mr-auto items-center">
                <div className="w-8 h-8 rounded-full bg-teal-600 flex items-center justify-center text-white flex-shrink-0">
                  <Sparkles className="w-4 h-4 animate-spin" />
                </div>
                <div className="bg-card border border-muted p-3 rounded-2xl rounded-tl-none shadow-sm flex items-center gap-1.5">
                  <span className="w-2 h-2 rounded-full bg-muted-foreground animate-bounce" style={{ animationDelay: "0ms" }} />
                  <span className="w-2 h-2 rounded-full bg-muted-foreground animate-bounce" style={{ animationDelay: "150ms" }} />
                  <span className="w-2 h-2 rounded-full bg-muted-foreground animate-bounce" style={{ animationDelay: "300ms" }} />
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </CardContent>

          {/* Chat Input form */}
          <div className="p-3 border-t bg-muted/10">
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
                className="flex-1 text-sm bg-card"
                disabled={chatMutation.isPending}
              />
              <Button type="submit" disabled={chatMutation.isPending || !input.trim()}>
                <Send className="w-4 h-4" />
              </Button>
            </form>
          </div>
        </Card>

        {/* Sidebar suggestions */}
        <div className="space-y-4">
          <Card className="border border-muted/80 shadow-md">
            <CardHeader className="py-3 px-4 border-b">
              <CardTitle className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                Suggested Prompts
              </CardTitle>
              <CardDescription className="text-[11px]">Click a prompt to ask the AI assistant directly.</CardDescription>
            </CardHeader>
            <CardContent className="p-3 space-y-2">
              {SUGGESTIONS.map((suggestion, idx) => (
                <button
                  key={idx}
                  onClick={() => handleSend(suggestion)}
                  disabled={chatMutation.isPending}
                  className="w-full text-left text-xs p-2.5 rounded-lg border border-transparent hover:border-indigo-100 hover:bg-indigo-50/50 dark:hover:bg-indigo-950/20 text-muted-foreground hover:text-indigo-600 dark:hover:text-indigo-400 transition-all flex items-center justify-between group"
                >
                  <span className="line-clamp-2 pr-2">{suggestion}</span>
                  <ArrowRight className="w-3.5 h-3.5 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0" />
                </button>
              ))}
            </CardContent>
          </Card>

          <Card className="border border-muted/80 shadow-md bg-indigo-50/30 dark:bg-indigo-950/10">
            <CardContent className="p-4 space-y-2">
              <h4 className="text-xs font-bold text-indigo-700 dark:text-indigo-400 flex items-center gap-1.5">
                <Sparkles className="w-3.5 h-3.5" />
                Natural Language Transactions
              </h4>
              <p className="text-[11px] text-muted-foreground leading-relaxed">
                You can say things like:
                <br />
                <span className="font-semibold text-foreground">"Spent 1500 on electricity bill using credit card"</span>
                <br />
                The AI will extract the amount, category, and payment method, log the expense automatically, and update your dashboard!
              </p>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
