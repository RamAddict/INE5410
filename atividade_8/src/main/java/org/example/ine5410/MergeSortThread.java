package org.example.ine5410;

import javax.annotation.Nonnull;
import java.util.ArrayList;
import java.util.List;
import java.lang.Thread;
import java.util.logging.Level;
import java.util.logging.Logger;

public class MergeSortThread<T extends Comparable<T>> implements MergeSort<T>{
    @Nonnull
    @Override
    public ArrayList<T> sort(@Nonnull final List<T> list) {
        //1. Há duas sub-tarefas, execute-as em paralelo usando threads
        //  (Para pegar um retorno da thread filha faça ela escrever em um ArrayList)
        
        if (list.size() <= 1)
            return new ArrayList<>(list);
        if (list.size() <= 256) {
            return new MergeSortSerial<T>().sort(list);
        }

        int mid = list.size() / 2;
        List<T> left = null;
        /* ~~~~ Execute essa linha paralelamente! ~~~~ */
        
        MyRun myrun = new MyRun(list.subList(0, mid));
        Thread thread = new Thread(myrun);
        thread.start();

        ArrayList<T> right = sort(list.subList(mid, list.size()));
        try {
            thread.join();
        } catch (InterruptedException ex) {
            Logger.getLogger(MergeSortThread.class.getName()).log(Level.SEVERE, null, ex);
        }
        left = myrun.output;
        return MergeSortHelper.merge(left, right);
    }
    public class MyRun implements Runnable {
        List<T> input;
        List<T> output;
        
        public MyRun(List<T> input) {
            this.input = input;
        }
        public void run(){
            output = sort(input);
            
        }
    }
}
