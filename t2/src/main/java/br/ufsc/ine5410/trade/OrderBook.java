package br.ufsc.ine5410.trade;

import javax.annotation.Nonnull;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.Semaphore;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

import static br.ufsc.ine5410.trade.Order.Type.*;
import java.util.logging.Level;
import java.util.logging.Logger;

public class OrderBook implements AutoCloseable {
    private final @Nonnull String stockCode;
    private final @Nonnull TransactionProcessor transactionProcessor;
    private final @Nonnull PriorityQueue<Order> sellOrders, buyOrders;
    private boolean closed = false;
    Thread post_boi = new Thread(new Runnable(){
        public void run(){
            tryMatch();
        }
    });

    public OrderBook(@Nonnull String stockCode,
                     @Nonnull TransactionProcessor transactionProcessor) {
        this.stockCode = stockCode;
        this.transactionProcessor = transactionProcessor;
        sellOrders = new PriorityQueue<>(100, new Comparator<Order>() {
            @Override
            public int compare(@Nonnull Order l, @Nonnull Order r) {
                return Double.compare(l.getPrice(), r.getPrice());
            }
        });
        buyOrders = new PriorityQueue<>(100, new Comparator<Order>() {
            @Override
            public int compare(@Nonnull Order l, @Nonnull Order r) {
                return Double.compare(r.getPrice(), l.getPrice());
            }
        });
        post_boi.start();
    }

    public synchronized void post(@Nonnull Order order) {
        es.submit(new Runnable() {
        public void run() {
            post_(order);
        }
        });
    }

    public synchronized void post_(@Nonnull Order order) {
        if (!order.getStock().equals(stockCode)) {
            String msg = toString() + " cannot process orders for " + order.getStock();
            throw new IllegalArgumentException(msg);
        }
        if (closed) {
            order.notifyCancellation();
            return;
        }
        
        (order.getType() == BUY ? buyOrders : sellOrders).add(order);
        
        order.notifyQueued();
    }

    private void tryMatch() {
        while (!closed)
        {
            Order sell, buy;
            // Enquanto ordens de venda e compra
            while ((sell = sellOrders.remove()) != null && (buy = buyOrders.remove()) != null) {
                // Se valor de venda for menor ou igual ao de compra
                if (sell.getPrice() <= buy.getPrice()) {
                    // Order sellRemove = sellOrders.remove();
                    // Order buyRemove = buyOrders.remove();
                    final Transaction trans = new Transaction(sellRemove, buyRemove);
                    sell.notifyProcessing();
                    buy.notifyProcessing();
                    transactionProcessor.process(OrderBook.this, trans);
                    assert sellRemove == sell;
                    assert buyRemove == buy;
                } else {
                    buyOrders.add(buy);
                    sellOrders.add(sell); // maybe wait?
                }
            }
        }
    }

    @Override
    public String toString() {
        return String.format("OrderBook(%s)", stockCode);
    }

    @Override
    public void close()  {
        if (closed) return;
        closed = true;
        //any future post() call will be a no-op

        for (Order order : sellOrders) order.notifyCancellation();
        sellOrders.clear();
        for (Order order : buyOrders) order.notifyCancellation();
        buyOrders.clear();
    }
}
