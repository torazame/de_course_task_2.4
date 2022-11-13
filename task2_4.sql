-- Приктическое задание к разделу 2.4 - PostgreSQL

/* a.Попробуйте вывести не просто самую высокую зарплату во всей команде,
   а вывести именно фамилию сотрудника с самой высокой зарплатой.
 */
SELECT last_name, salary
FROM employees
WHERE salary = (SELECT MAX(salary) FROM employees);


-- b. Попробуйте вывести фамилии сотрудников в алфавитном порядке
SELECT last_name
FROM employees
ORDER BY last_name ASC;


-- c.     Рассчитайте средний стаж для каждого уровня сотрудников
SELECT t.grade, ROUND(AVG(t.length_of_service), 1) AS avg_length_of_service
FROM
    (SELECT grade, (CURRENT_DATE - employment_start) / 365 AS length_of_service
     FROM employees) t
GROUP BY t.grade
ORDER BY 2;


-- d.     Выведите фамилию сотрудника и название отдела, в котором он работает
SELECT e.first_name, e.last_name, d.dep_name
FROM employees e
JOIN departments d ON e.dep_id = d.dep_id;


/* e.     Выведите название отдела и фамилию сотрудника с самой высокой зарплатой в
   данном отделе и саму зарплату также.
 */
SELECT d.dep_name, t.last_name, t.salary FROM
    (SELECT e.dep_id, e.last_name, e.salary, MAX(e.salary) OVER (PARTITION BY e.dep_id) AS max_salary
    FROM employees e) t
JOIN departments d ON d.dep_id = t.dep_id
WHERE t.salary = t.max_salary
ORDER BY salary;


/* f. *Выведите название отдела, сотрудники которого получат наибольшую премию по итогам года.
   Как рассчитать премию можно узнать в последнем задании предыдущей домашней работы
 */
WITH tmp_tbl AS (SELECT *,
                        CASE result
                            WHEN 'A' THEN 0.2
                            WHEN 'B' THEN 0.1
                            WHEN 'C' THEN 0
                            WHEN 'D' THEN -0.1
                            WHEN 'E' THEN -0.2
                            END AS performance_coef
                 FROM bonuses),
    tmp_tbl2 AS (
        SELECT emp_id, SUM(performance_coef) + 1 AS yearly_bonus_coef
        FROM tmp_tbl
        GROUP BY emp_id
    ),
    tbl_bonus AS (
        SELECT e.*, COALESCE(t.yearly_bonus_coef, 0) yearly_bonus_coef
        FROM employees e
        LEFT JOIN tmp_tbl2 t
        ON e.emp_id = t.emp_id
    ),
    tbl_agg_bonus AS (
        SELECT d.dep_name, (tb.salary * tb.yearly_bonus_coef) AS yearly_bonus
        FROM tbl_bonus tb
        JOIN departments d
        ON d.dep_id = tb.dep_id
            )
    SELECT dep_name, SUM(yearly_bonus) as total_bonus
        FROM tbl_agg_bonus
    GROUP BY dep_name
    ORDER BY total_bonus DESC
    LIMIT 1;


/* g.    *Проиндексируйте зарплаты сотрудников с учетом коэффициента премии.
   Для сотрудников с коэффициентом премии больше 1.2 – размер индексации составит 20%,
   для сотрудников с коэффициентом премии от 1 до 1.2 размер индексации составит 10%.
   Для всех остальных сотрудников индексация не предусмотрена.
 */
WITH tmp_tbl AS (SELECT *,
                        CASE result
                            WHEN 'A' THEN 0.2
                            WHEN 'B' THEN 0.1
                            WHEN 'C' THEN 0
                            WHEN 'D' THEN -0.1
                            WHEN 'E' THEN -0.2
                            END AS performance_coef
                 FROM bonuses),
    tmp_tbl2 AS (
        SELECT emp_id, SUM(performance_coef) + 1 AS yearly_bonus_coef
        FROM tmp_tbl
        GROUP BY emp_id
    ),
    tbl_bonus AS (
        SELECT e.*, d.dep_name,
               COALESCE(t.yearly_bonus_coef, 0) yearly_bonus_coef
        FROM employees e
        LEFT JOIN tmp_tbl2 t
        ON e.emp_id = t.emp_id
        JOIn departments d
        ON d.dep_id = e.dep_id
    )
SELECT *,
       CASE
           WHEN yearly_bonus_coef > 1.2 THEN 1.2
           WHEN yearly_bonus_coef BETWEEN 1 AND 1.2 THEN 1.1
           ELSE 1
        END AS increase_coef,
    salary *
       CASE
           WHEN yearly_bonus_coef > 1.2 THEN 1.2
           WHEN yearly_bonus_coef BETWEEN 1 AND 1.2 THEN 1.1
           ELSE 1
        END AS new_salary
FROM tbl_bonus;


/* h. ***По итогам индексации отдел финансов хочет получить следующий отчет:
   вам необходимо на уровень каждого отдела вывести следующую информацию:
   i.     Название отдела
   ii.     Фамилию руководителя
   iii.     Количество сотрудников
   iv.     Средний стаж
   v.     Средний уровень зарплаты
   vi.     Количество сотрудников уровня junior
   vii.     Количество сотрудников уровня middle
   viii.     Количество сотрудников уровня senior
   ix.     Количество сотрудников уровня lead
   x.     Общий размер оплаты труда всех сотрудников до индексации
   xi.     Общий размер оплаты труда всех сотрудников после индексации
   xii.     Общее количество оценок А
   xiii.     Общее количество оценок B
   xiv.     Общее количество оценок C
   xv.     Общее количество оценок D
   xvi.     Общее количество оценок Е
   xvii.     Средний показатель коэффициента премии
   xviii.     Общий размер премии.
   xix.     Общую сумму зарплат(+ премии) до индексации
   xx.     Общую сумму зарплат(+ премии) после индексации(премии не индексируются)
   xxi.     Разницу в % между предыдущими двумя суммами(первая/вторая)
 */

SELECT d.dep_name,
       d.manager,
       d.num_employees,
       emp_stats.avg_service_length,
       emp_stats.avg_salary,
       emp_stats.jun_employees,
       emp_stats.mid_employees,
       emp_stats.senior_employees,
       emp_stats.lead_employees,
       emp_stats.salary_before_increase,
       emp_stats.salary_after_increase,
       COALESCE(bon.A_count, 0) A_count,
       COALESCE(bon.B_count, 0) B_count,
       COALESCE(bon.C_count, 0) C_count,
       COALESCE(bon.D_count, 0) D_count,
       COALESCE(bon.E_count, 0) E_count,
       emp_stats.avg_bonus_coef,
       emp_stats.total_bonus,
       emp_stats.total_salary_bonus_before_inc,
       emp_stats.total_salary_bonus_after_inc,
       emp_stats.salaries_diff_perc
FROM departments d
JOIN (
    WITH tmp_tbl AS (SELECT *,
                            CASE result
                                WHEN 'A' THEN 0.2
                                WHEN 'B' THEN 0.1
                                WHEN 'C' THEN 0
                                WHEN 'D' THEN -0.1
                                WHEN 'E' THEN -0.2
                                END AS performance_coef
                     FROM bonuses),
            tmp_tbl2 AS (
                    SELECT emp_id, SUM(performance_coef) + 1 AS yearly_bonus_coef
                    FROM tmp_tbl
                    GROUP BY emp_id
                ),
            tbl_bonus AS (
                    SELECT e.*, d.dep_name,
                           COALESCE(t.yearly_bonus_coef, 0) yearly_bonus_coef
                    FROM employees e
                    LEFT JOIN tmp_tbl2 t
                    ON e.emp_id = t.emp_id
                    JOIn departments d
                    ON d.dep_id = e.dep_id
                ),
            fin_table AS (
            SELECT *,
                    CASE
                        WHEN yearly_bonus_coef > 1.2 THEN 1.2
                        WHEN yearly_bonus_coef BETWEEN 1 AND 1.2 THEN 1.1
                        ELSE 1
                            END AS increase_coef,
                    salary *
                    CASE
                        WHEN yearly_bonus_coef > 1.2 THEN 1.2
                        WHEN yearly_bonus_coef BETWEEN 1 AND 1.2 THEN 1.1
                        ELSE 1
                        END AS new_salary
            FROM tbl_bonus
        )
        SELECT dep_id ,
           ROUND(AVG((CURRENT_DATE - employment_start) / 365), 2) AS avg_service_length,
           ROUND(AVG(new_salary), 2) AS avg_salary,
           SUM(CASE WHEN grade = 'JUN' THEN 1 ELSE 0 END) AS jun_employees,
           SUM(CASE WHEN grade = 'MID' THEN 1 ELSE 0 END) AS mid_employees,
           SUM(CASE WHEN grade = 'SEN' THEN 1 ELSE 0 END) AS senior_employees,
           SUM(CASE WHEN grade = 'LEAD' THEN 1 ELSE 0 END) AS lead_employees,
           SUM(salary) AS salary_before_increase,
           SUM(new_salary) AS salary_after_increase,
           ROUND(AVG(yearly_bonus_coef), 2) AS avg_bonus_coef,
           SUM(yearly_bonus_coef * salary) AS total_bonus,
           SUM(salary + (yearly_bonus_coef * salary)) total_salary_bonus_before_inc,
           SUM(new_salary + (yearly_bonus_coef * salary)) total_salary_bonus_after_inc,
           ROUND((SUM(new_salary + (yearly_bonus_coef * salary)) /
                SUM(salary + (yearly_bonus_coef * salary)) - 1) * 100, 2)
                    AS salaries_diff_perc
        FROM fin_table
        GROUP BY dep_id
        ) emp_stats
    ON d.dep_id = emp_stats.dep_id
    LEFT JOIN
        (SELECT e.dep_id,
               SUM(CASE WHEN result = 'A' THEN 1 ELSE 0 END) AS A_count,
               SUM(CASE WHEN result = 'B' THEN 1 ELSE 0 END) AS B_count,
               SUM(CASE WHEN result = 'C' THEN 1 ELSE 0 END) AS C_count,
               SUM(CASE WHEN result = 'D' THEN 1 ELSE 0 END) AS D_count,
               SUM(CASE WHEN result = 'E' THEN 1 ELSE 0 END) AS E_count
        FROM bonuses b
        JOIN employees e
        ON b.emp_id = e.emp_id
        GROUP BY e.dep_id) bon
    ON bon.dep_id = d.dep_id
