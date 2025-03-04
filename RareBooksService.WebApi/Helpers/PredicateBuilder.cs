using System;
using System.Linq;
using System.Linq.Expressions;

namespace RareBooksService.WebApi.Helpers
{
    /// <summary>
    /// Класс для построения динамических предикатов LINQ
    /// </summary>
    public static class PredicateBuilder
    {
        /// <summary>
        /// Создает предикат, который всегда возвращает true
        /// </summary>
        public static Expression<Func<T, bool>> True<T>() { return f => true; }

        /// <summary>
        /// Создает предикат, который всегда возвращает false
        /// </summary>
        public static Expression<Func<T, bool>> False<T>() { return f => false; }

        /// <summary>
        /// Объединяет два предиката с помощью оператора OR
        /// </summary>
        public static Expression<Func<T, bool>> Or<T>(this Expression<Func<T, bool>> expr1, Expression<Func<T, bool>> expr2)
        {
            var invokedExpr = Expression.Invoke(expr2, expr1.Parameters.Cast<Expression>());
            return Expression.Lambda<Func<T, bool>>(Expression.OrElse(expr1.Body, invokedExpr), expr1.Parameters);
        }

        /// <summary>
        /// Объединяет два предиката с помощью оператора AND
        /// </summary>
        public static Expression<Func<T, bool>> And<T>(this Expression<Func<T, bool>> expr1, Expression<Func<T, bool>> expr2)
        {
            var invokedExpr = Expression.Invoke(expr2, expr1.Parameters.Cast<Expression>());
            return Expression.Lambda<Func<T, bool>>(Expression.AndAlso(expr1.Body, invokedExpr), expr1.Parameters);
        }
    }
} 