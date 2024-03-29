//+------------------------------------------------------------------+
//|                                                      Media42.mq5 |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#include  <Trade/SymbolInfo.mqh>

input ENUM_TRADE_REQUEST_ACTIONS TipoAction = TRADE_ACTION_DEAL;
input double   Distancia         = 5;
input int      PeriodoLongo      = 72;         // Período Média Longa
input int      PeriodoCurto      = 42;         // Período Média Curta
input double   SL                = 100;        // Stop Loss
input double   TP                = 300;        // Take Profit
input double   Volume            = 1;          // Volume
input string   inicio            = "09:05";    // Horário de Início
input string   termino           = "17:00";    // Horário de Termino
input string   fechamento        = "17:30";    // Horário de Início

int handlemedialonga, handlemediacurta; //Manipuladores dos dois indicadores

//CTrade negocio; // Classe responsável pela execução de negócios
CSymbolInfo simbolo; // Classe responsável pelos dados do ativo

//--- Estruturas de negociação
MqlTradeRequest request;
MqlTradeResult result;
MqlTradeCheckResult check_result;

int magic = 1111; // Número mágico das ordens

//---Estruturas de tempo para manipulação de horários
MqlDateTime horario_inicio, horario_termino, horario_fechamento, horario_atual;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   { 
   if(!simbolo.Name(_Symbol))
   {
      printf("Ativo inválido!");
      return INIT_FAILED;
   }
   
   handlemediacurta = iCustom(_Symbol, _Period, "MediaMovel", PeriodoCurto);
   handlemedialonga = iCustom(_Symbol, _Period, "MediaMovel", PeriodoLongo);
   
   if(handlemediacurta == INVALID_HANDLE || handlemedialonga == INVALID_HANDLE)
   {   
      Print("Erro na criação dos manipuladores");
      return INIT_FAILED;
   }  
   
   if(PeriodoLongo <= PeriodoCurto)
   {
      Print("Parâmetros de médias incorretos");
      return INIT_FAILED;
   }
//---
   return(INIT_SUCCEEDED);
  }
  
   TimeToStruct(StringToTime(inicio), horario_inicio);
   TimeToStruct(StringToTime(termino), horario_termino);
   TimeToStruct(StringToTime(fechamento), horario_fechamento);
   
   if(horario_inicio.hour > horario_termino.hour || (horario_inicio.hour == horario_termino.hour && horario_inicio.min > horario_termino.min))
   {
      printf("Parâmetros de horário inválidos!");
      return INIT_FAILED;
   }
   
   if(horario_termino.hour > horario_fechamento.hour || (horario_termino.hour == horario_fechamento.hour && horario_termino.min > horario_fechamento.min))
   {
      printf("Parâmetros de horário inválidos!");
      return INIT_FAILED;
   }
   
   // Checar se ordem é pendente ou a mercado e determinar trade action
   if(TipoAction != TRADE_ACTION_DEAL && TipoAction != TRADE_ACTION_PENDING)
   {
      printf("Tipo de ordem não permitido");
      return INIT_FAILED;
   }
   
   return(INIT_SUCCEEDED);
  
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
    printf("Deinit reason: %d", reason);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
 if(!simbolo.RefreshRates())
      return;
   
   if(HorarioEntrada())
   {
      if(SemPosicao() && SemOrdem())
      {
         int resultado_cruzamento = Cruzamento();
         if(resultado_cruzamento == 1)
            Compra();
         if(resultado_cruzamento == -1)
            Venda();
      }
   }
   
   if(HorarioFechamento() || !SemOrdem())
   {
      if(!SemPosicao())
         Fechar();
   }
 
 
 
bool HorarioEntrada()
{
   TimeToStruct(TimeCurrent(), horario_atual);
   if(horario_atual.hour >= horario_inicio.hour && horario_atual.hour <= horario_termino.hour)
   {
      if(horario_atual.hour == horario_inicio.hour)
         if(horario_atual.min >= horario_inicio.min)
            return true;
         else
            return false;
            
      if(horario_atual.hour == horario_termino.hour)
         if(horario_atual.min <= horario_termino.min)
            return true;
         else
            return false;
            
      return true;
   }
   
   return false;
}
  
bool HorarioFechamento()
{
   TimeToStruct(TimeCurrent(), horario_atual);
   if(horario_atual.hour >= horario_fechamento.hour)
   {
      if(horario_atual.hour == horario_fechamento.hour)
         if(horario_atual.min <= horario_fechamento.min)
            return false;
         else 
            return true;   
            
      
      return true;
   }
   
   return false;
}
  
void Compra()
{
   double price;
   if(TipoAction == TRADE_ACTION_DEAL)
      price = simbolo.Ask();
   else 
      price = simbolo.Bid() - Distancia;
   double stoploss    =  simbolo.NormalizePrice(price - SL);
   double takeprofit  =  simbolo.NormalizePrice(price + TP);
   //negocio.Buy(Volume,NULL, price, stoploss, takeprofit, "Compra CruzamentoMediaEA");
   
   //Limpar informações das estruturas
   ZeroMemory(request);
   ZeroMemory(result);
   ZeroMemory(check_result);
   
   //--- Preenchimento da requisição
   request.action          =  TipoAction;
   request.magic           =  magic;
   request.symbol          =  _Symbol;
   request.volume          =  Volume;
   request.price           =  price;
   request.sl              =  stoploss;
   request.tp              =  takeprofit;
   if(TipoAction == TRADE_ACTION_DEAL)
      request.type         =  ORDER_TYPE_BUY;
   else
      request.type         = ORDER_TYPE_BUY_LIMIT;
   request.type_filling    = ORDER_FILLING_RETURN;
   request.type_time       = ORDER_TIME_DAY;
   request.comment         = "Compra CruzamentoMediaEA";
   
   
    //--- Checagem e envio de ordens
    ResetLastError();
    if(!OrderCheck(request, check_result))
    {
      PrintFormat("Erro em OrderCheck: %d", GetLastError());
      PrintFormat("Código de retorno: %d", check_result.retcode);
      return;
    }
    
    if(!OrderSend(request, result))
    {
      PrintFormat("Erro em OrderSend: %d", GetLastError());
      PrintFormat("Código de retorno: %d", result.retcode);
    }
    

}  
  
void Venda()
{
   double price;
   if(TipoAction==TRADE_ACTION_DEAL)
      price= simbolo.Bid();
   else 
      price= simbolo.Ask() + Distancia;
   double stoploss    =  simbolo.NormalizePrice(price + SL);
   double takeprofit  =  simbolo.NormalizePrice(price - TP);
   //negocio.Sell(Volume,NULL, price, stoploss, takeprofit, "Venda CruzamentoMediaEA");

   //Limpar informações das estruturas
   ZeroMemory(request);
   ZeroMemory(result);
   ZeroMemory(check_result);
   
   //--- Preenchimento da requisição
   request.action          =  TipoAction;
   request.magic           =  magic;
   request.symbol          =  _Symbol;
   request.volume          =  Volume;
   request.price           =  price;
   request.sl              =  stoploss;
   request.tp              =  takeprofit;
   if(TipoAction == TRADE_ACTION_DEAL)
      request.type         = ORDER_TYPE_SELL;
   else
      request.type         = ORDER_TYPE_SELL_LIMIT;
   request.type_filling    = ORDER_FILLING_RETURN;
   request.type_time       = ORDER_TIME_DAY;
   request.comment         = "Venda CruzamentoMediaEA";

   //--- Checagem e envio de ordens
    ResetLastError();
    if(!OrderCheck(request, check_result))
    {
      PrintFormat("Erro em OrderCheck: %d", GetLastError());
      PrintFormat("Código de retorno: %d", check_result.retcode);
      return;
    }
    
    if(!OrderSend(request, result))
    {
      PrintFormat("Erro em OrderSend: %d", GetLastError());
      PrintFormat("Código de retorno: %d", result.retcode);
    }
}  
  
  
void Fechar()
{
   if(OrdersTotal()!=0)
   {
      for(int i = OrdersTotal()-1; i>=0; i--)
      {
         OrderGetTicket(i);
         if(OrderGetString(ORDER_SYMBOL)==_Symbol)
         {
            ulong ticket = OrderGetTicket (i);
            if(OrderGetString(ORDER_SYMBOL) == _Symbol)
            {
               ZeroMemory(request);
               ZeroMemory(result);
               ZeroMemory(check_result);
               request.action    = TRADE_ACTION_REMOVE;
               request.order     = ticket;
               
               //--- Checagem de envio de ordens
               ResetLastError();
               if(!OrderCheck(request, check_result))
               {
                  PrintFormat("Erro em OrderCheck: %d", GetLastError());
                  PrintFormat("Código de retorno: %d", check_result.retcode);
                  return;
               }
               
               if (!OrderSend(request, result))
               {
                  PrintFormat("Erro em OrderSend: %d", GetLastError());
                  PrintFormat("Código de retorno: %d", result.retcode);
               }
            }
         }
      }
  }
   
   // Verificação de posição aberta
   if(!PositionSelect(_Symbol))
      return;
   
   //Limpar informações das estruturas
   ZeroMemory(request);
   ZeroMemory(result);
   ZeroMemory(check_result);
   
   //--- Preenchimento da requisição
   request.action          =  TRADE_ACTION_DEAL;
   request.magic           =  magic;
   request.symbol          =  _Symbol;
   request.volume          =  Volume;
   request.type_filling    =  ORDER_FILLING_RETURN;
   request.comment         =  "Fechamento CruzamentoMediaEA";
   
   long tipo = PositionGetInteger(POSITION_TYPE);
   if(tipo == POSITION_TYPE_BUY)
   {
      //negocio.Sell(Volume, NULL, 0, 0, 0, "Fechamento CruzamentoMediaEA");
      request.price        = simbolo.Bid();
      request.type         = ORDER_TYPE_SELL;
   }
   else
      //negocio7.Buy(Volume, NULL, 0, 0, 0, "Fechamento CruzamentoMediaEA");
      request.price        = simbolo.Ask();
      request.type         = ORDER_TYPE_BUY;
      
      //--- Checagem e envio de ordens
    ResetLastError();
    if(!OrderCheck(request, check_result))
    {
      PrintFormat("Erro em OrderCheck: %d", GetLastError());
      PrintFormat("Código de retorno: %d", check_result.retcode);
      return;
    }
    
    if(!OrderSend(request, result))
    {
      PrintFormat("Erro em OrderSend: %d", GetLastError());
      PrintFormat("Código de retorno: %d", result.retcode);
    }
}  
  
  
bool SemPosicao()
{
   return !PositionSelect(_Symbol);
}


bool SemOrdem()
{
   for(int i = OrdersTotal()-1; i>=0; i--)
   {
      OrderGetTicket(i);
      if(OrderGetString(ORDER_SYMBOL)==_Symbol)
         return false;
   }
   return true; 
}
  


int Cruzamento()
{
   double MediaCurta[], MediaLonga[];
   ArraySetAsSeries(MediaCurta, true);
   ArraySetAsSeries(MediaLonga, true);
   CopyBuffer(handlemediacurta, 0, 0, 2, MediaCurta);
   CopyBuffer(handlemedialonga, 0, 0, 2, MediaLonga);
   
   //Compra
   if(MediaCurta[1] <= MediaLonga[1] && MediaCurta[0] > MediaLonga[0])
      return 1;
      
   //Venda
   if(MediaCurta[1] >= MediaLonga[1] && MediaCurta[0] < MediaLonga[0])
      return -1;
      
      
   
   return 0;
}
  }
//+------------------------------------------------------------------+
