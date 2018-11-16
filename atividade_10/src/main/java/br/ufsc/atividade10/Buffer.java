package br.ufsc.atividade10;

import javax.annotation.Nonnull;
import java.util.concurrent.locks.*;
import java.util.Iterator;
import java.util.LinkedList;
import java.util.List;
import java.util.Stack;
import static br.ufsc.atividade10.Piece.Type.*;

public class Buffer {
    private final int maxSize;
    private static java.util.LinkedList buffer;
    private int XAmmount;
    private int OAmmount;
    private Lock Omutex;
    private Lock Xmutex;
    public Buffer() {
        this(10);
    }
    public Buffer(int maxSize) {
        this.maxSize = maxSize;
        buffer = new java.util.LinkedList<>();
        XAmmount = 0;
        OAmmount = 0;
        Omutex = new ReentrantLock(false);
        Xmutex = new ReentrantLock(false);
    }

    public synchronized void add(Piece piece) throws InterruptedException {
        synchronized(buffer) {
            
            while (buffer.size() >= maxSize) {
                try{buffer.wait();}
                catch (InterruptedException exception) {System.err.println("too much sh!t");}
            }
            
            while (OAmmount == (maxSize -1) && piece.getType() == Piece.Type.O) {
                try{buffer.wait();}
                catch (InterruptedException exception) {System.err.println("too many Oreos");}
            }
                
            while (XAmmount == (maxSize -2) && piece.getType() == Piece.Type.X) {
                try{buffer.wait();}
                catch (InterruptedException exception) {System.err.println("too many SpaghettiOs");}
            }

            if (piece.getType() == O){
                Omutex.lock();
                try {OAmmount++;}
                finally {Omutex.unlock();}
            } else {
                Xmutex.lock();
                try {XAmmount++;}
                finally {Xmutex.unlock();}
            }
            buffer.push(piece);
            buffer.notifyAll();
            
        }
    }

    public synchronized void takeOXO(@Nonnull List<Piece> xList,
                                     @Nonnull List<Piece> oList) throws InterruptedException {
            
            while (XAmmount < 1 || OAmmount < 2) {
                try{buffer.wait();}
                catch (InterruptedException exception) {System.err.println("too much sh!t");}
            }
            buffer.removeFirstOccurrence(O);
            
            Omutex.lock();
            try {OAmmount--;}
            finally {Omutex.unlock();}
            
            buffer.removeFirstOccurrence(X);
            
            Xmutex.lock();
            try {XAmmount--;}
            finally {Xmutex.unlock();}
            
            buffer.removeFirstOccurrence(O);
            
            Omutex.lock();
            try {OAmmount--;}
            finally {Omutex.unlock();}
            
            
            buffer.notifyAll();
        
    }
}
