package br.ufsc.atividade11;

import javax.annotation.Nonnull;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

public class Market {
    private Map<Product, Double> prices = new HashMap<>();
    private Map<Product, ReentrantReadWriteLock> locks = new HashMap<>();
    private Map<Product, Condition> conditions = new HashMap<>();
    
    public Market() {
        for (Product product : Product.values()) {
            prices.put(product, 1.99);
            ReentrantReadWriteLock rwlock = new ReentrantReadWriteLock();
            locks.put(product, rwlock);
            conditions.put(product, rwlock.writeLock().newCondition());
        }
    }

    public void setPrice(@Nonnull Product product, double value) {
        
        (locks.get(product)).writeLock().lock();
        prices.put(product, value);
        if (prices.get(product) > value)
            conditions.get(product).signalAll();
        (locks.get(product)).writeLock().unlock();
    }

    public double take(@Nonnull Product product) {
        locks.get(product).readLock().lock();
        return prices.get(product);
    }

    public void putBack(@Nonnull Product product) {
        locks.get(product).readLock().unlock();
    }

    public double waitForOffer(@Nonnull Product product,
                               double maximumValue) throws InterruptedException {
        //deveria esperar até que prices.get(product) <= maximumValue
        locks.get(product).writeLock().lock();
        while (prices.get(product) <= maximumValue)
            conditions.get(product).await();
        take(product);
        locks.get(product).writeLock().unlock();
        return prices.get(product);
    }

    public double pay(@Nonnull Product product) {
        locks.get(product).readLock().unlock();
        return prices.get(product);
    }
}
