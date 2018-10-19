package org.example.ine5410;

import com.google.common.base.Stopwatch;
import org.testng.Assert;
import org.testng.annotations.DataProvider;
import org.testng.annotations.Test;

import javax.annotation.Nonnull;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.TimeUnit;

import static org.testng.Assert.*;

public class MergeSortTest {
    @DataProvider
    public static Object[][] sortData() {
        int sizes[] = {0, 1, 2, 4, 8, 1 << 18};
        return new Object[][] {
                {new MergeSortSerial<Integer>(), sizes},
                {new MergeSortThread<Integer>(), sizes},
                {new MergeSortExecutor<Integer>(), sizes}
        };
    }

    @Test(dataProvider = "sortData", threadPoolSize = 4)
    public void testSort(@Nonnull MergeSort<Integer> sorter, int[] sizes) {
        for (int i = 0; i < 4; i++) {
            for (int size : sizes) {
                String msg = String.format("i=%d, size=%d", i, size);
                List<Integer> data = new ArrayList<>();
                for (int j = 0; j < size; j++) data.add((int) (Math.random() * 1000000));

                ArrayList<Integer> expected = new ArrayList<>(data);
                Collections.sort(expected);

                ArrayList<Integer> actual = sorter.sort(data);
                if (data.size() > 100) {
                    //avoid huuuuge logs
                    //noinspection SimplifiedTestNGAssertion
                    Assert.assertTrue(actual.equals(expected), msg);
                } else {
                    Assert.assertEquals(actual, expected, msg);
                }
            }
        }
    }

    @Test
    public void testSpeed() {
        List<Integer> data = new ArrayList<>();
        for (int j = 0; j < 131072; j++) data.add((int) (Math.random() * 1000000));

        double executorAvg = 0, threadAvg = 0, serialAvg = 0;
        for (int i = 0; i < 7; i++) {
            Stopwatch sw = Stopwatch.createStarted();
            new MergeSortSerial<Integer>().sort(data);
            serialAvg += sw.elapsed(TimeUnit.MILLISECONDS);

            sw.reset().start();
            new MergeSortExecutor<Integer>().sort(data);
            executorAvg += sw.elapsed(TimeUnit.MILLISECONDS);

            sw.reset().start();
            new MergeSortThread<Integer>().sort(data);
            threadAvg += sw.elapsed(TimeUnit.MILLISECONDS);

            Runtime.getRuntime().gc();
            try {
                Thread.sleep(100);
            } catch (InterruptedException ignored) {}
        }
        executorAvg /= 7;
        threadAvg /= 7;
        serialAvg /= 7;

        System.out.printf("executorAvg: %.3f, threadAvg: %.3f serialAvg: %.3f\n",
                executorAvg, threadAvg, serialAvg);
        Assert.assertTrue(executorAvg < 1.6*serialAvg);
        Assert.assertTrue(threadAvg < 1.6*serialAvg);

    }

}