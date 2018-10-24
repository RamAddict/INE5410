package org.example.ine5410;

import javax.annotation.Nonnull;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;

public class MergeSortExecutor<T extends Comparable<T>> implements MergeSort<T> {
    
    @Nonnull
    @Override
    public ArrayList<T> sort(@Nonnull List<T> list) {
        //1. Crie um Cached ExecutorService
        // (Executors Single thread ou fixed thread pool) causarão starvation!
        //2. Submete uma tarefa incial ao executor
        //3. Essa tarefa inicial vai se subdividir em novas tarefas enviadas para
        //   o mesmo executor
        //4. Desligue o executor ao sair!

        if (list.size() <= 1100) // wtf how is this not enough
            return new MergeSortSerial<T>().sort(list);

        /* ~~~~ O tipo do executor precisa ser Cached!!!! ~~~~ */
        ExecutorService executor = Executors.newCachedThreadPool();
        
        int mid = list.size() / 2;
        List<T> left = null;
        Future<List<T>> future;
        List<T> temp = list;
        
        
        
        /* ~~~~ Execute essa linha paralelamente! ~~~~ */
        future = executor.submit(new MyCallable(temp.subList(0, mid)));    
        List<T> right = sort(list.subList(mid, list.size()));

        
        try {
            // get ja espera pela thread terminar
            left = future.get();
        } catch (Exception e) {
            e.printStackTrace();
        }
        return MergeSortHelper.merge(left, right);

        //throw new UnsupportedOperationException("Me implemente!");
    }
    public class MyCallable implements Callable<List<T>>{
        List<T> input;
        MyCallable(List<T> inpt) {
            input = inpt;
        }
        @Override
        public List<T> call() throws Exception{
            return MergeSortExecutor.this.sort(input);
        }
    }
}
